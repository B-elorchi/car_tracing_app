import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Nécessaire pour FieldValue.serverTimestamp
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path; // Pour manipuler les chemins de fichiers
import 'package:flutter/foundation.dart'; // For kIsWeb and Uint8List
import 'package:mime/mime.dart'; // AJOUTÉ: Pour détecter le type MIME du fichier (à ajouter dans pubspec.yaml)
import 'package:uuid/uuid.dart'; // AJOUTÉ: Pour générer des IDs uniques (à ajouter dans pubspec.yaml)


// AJOUTÉ : Importation de VehicleController
import 'package:projectkhadija/controller/VehicleController.dart'; // Assurez-vous du chemin correct

// FILE NAMING CONVENTION:
// Rename this file from 'AddVehicleScreen.dart' to 'add_vehicle_screen.dart'
// Dart best practices recommend lower_case_with_underscores for file names.

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final TextEditingController modelController = TextEditingController();
  final TextEditingController licenseController = TextEditingController();
  bool isAvailable = true;
  File? selectedImageFile; // For mobile/desktop (actual file path, if available)
  Uint8List? selectedImageBytes; // For web (and general byte data for upload)
  String? _selectedFileName; // To store the original name from the picker

  bool _isLoading = false;
  final SupabaseClient supabase = Supabase.instance.client;
  // AJOUTÉ : Instance de VehicleController
  final VehicleController _vehicleController = VehicleController();

  final Uuid uuid = Uuid(); // Instance pour générer des UUIDs


  // Unified method to choose an image
  Future<void> _pickImage() async {
    setState(() {
      selectedImageFile = null;
      selectedImageBytes = null;
      _selectedFileName = null; // Reset the file name
    });

    if (kIsWeb) {
      final XFile? pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          selectedImageBytes = bytes;
          _selectedFileName = pickedFile.name; // Use the name from XFile for web
        });
      }
    } else if (Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS) {
      final XFile? pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          selectedImageFile = File(pickedFile.path); // Keep for potential other uses
          selectedImageBytes = bytes;
          _selectedFileName = path.basename(pickedFile.path); // Use basename for native paths
        });
      }
    } else { // Desktop (Windows, Linux, macOS)
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // Request byte data directly
      );
      if (result != null && result.files.single.bytes != null) {
        setState(() {
          selectedImageBytes = result.files.single.bytes;
          selectedImageFile = File(result.files.single.path!); // Path is guaranteed for desktop
          _selectedFileName = result.files.single.name; // Use the name from FilePickerResult
        });
      }
    }
  }

  // Unified function to add the vehicle and image
  Future<void> addVehicle() async {
    // 1. التحقق من المدخلات
    if (modelController.text.isEmpty || licenseController.text.isEmpty || selectedImageBytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tous les champs sont obligatoires')));
      return;
    }

    setState(() {
      _isLoading = true; // تفعيل حالة التحميل
    });

    ScaffoldMessengerState? messenger;
    if (mounted) messenger = ScaffoldMessenger.of(context);

    try {
      // 2. تحديد اسم الملف الأساسي و Unique ID
      String baseFileName = _selectedFileName ?? 'vehicle.png';
      String uniqueIdForFile = uuid.v4(); // استخدام UUID لضمان تفرد أكبر

      // 3. تحديد نوع الملف (MIME Type) - مهم جداً لـSupabase Storage
      // استخدام مكتبة 'mime' للحصول على mimeType أكثر دقة.
      String? mimeType = lookupMimeType(baseFileName);
      if (mimeType == null || !mimeType.startsWith('image/')) {
        mimeType = 'image/png'; // قيمة افتراضية إذا لم يتم تحديد نوع الصورة بشكل صحيح
      }

      // 4. بناء المسار الكامل للملف داخل الـBucket
      // هذا هو الجزء الأهم لي كنصححوه باش نتفاداو تكرار "vehicles/vehicles/"
      // غتكون عندك فولدر باسم Immatriculation ديال السيارة
      // مثال: "mon-immatriculation-ABC/UUID_unique_nom_original.png"
      final String filePathInBucket = '${licenseController.text.replaceAll(' ', '_')}/$uniqueIdForFile-${baseFileName.replaceAll(' ', '_')}'; // استخدام licenseController.text كفولدر + تنظيف الأسماء

      // 5. طباعة للـDebugging - هادو لي خاصك تشوفهم في الـConsole
      debugPrint('--- Début Upload Image ---');
      debugPrint('Bucket Name: vehicles');
      debugPrint('File Path IN Bucket (MUST NOT START WITH "vehicles/"): $filePathInBucket');
      debugPrint('MIME Type: $mimeType');
      debugPrint('--- Fin Debugging Pré-Upload ---');

      // 6. رفع الصورة إلى Supabase Storage
      await supabase.storage
          .from('vehicles') // اسم الـBucket ديالك (هذا هو "vehicles" الأول في الـURL)
          .uploadBinary(
        filePathInBucket, // هذا هو المسار الذي نتحكم فيه الآن (لا يحتوي على "vehicles/" مرة أخرى)
        selectedImageBytes!,
        fileOptions: FileOptions(
          cacheControl: '3600', // تخزين مؤقت لمدة ساعة
          upsert: true, // تسمح بتحديث ملف بنفس الاسم والمسار (مفيدة لإعادة الرفع لنفس السيارة)
          contentType: mimeType, // نوع الملف المحدد ديناميكياً
        ),
      );

      // 7. الحصول على الرابط العمومي للصورة المرفوعة
      // الرابط سيتم إنشاؤه تلقائيًا بـ: base_url + /bucket_name/ + filePathInBucket
      String imageUrl = supabase.storage.from('vehicles').getPublicUrl(filePathInBucket);

      // 8. طباعة الرابط النهائي للـDebugging
      debugPrint('Image uploaded successfully. Final Public URL: $imageUrl');

      // 9. استخدام VehicleController لإضافة المركبة (مع الرابط الصحيح)
      await _vehicleController.addVehicle(
        model: modelController.text,
        licensePlate: licenseController.text, // هذا سيكون ID الوثيقة في Firestore
        isAvailable: isAvailable,
        imageUrl: imageUrl,
        // homeLocation سيكون null هنا، أو يمكنك إضافة منطق لتحديده
      );

      // 10. النجاح ومسح الحقول
      if (messenger != null) {
        messenger.showSnackBar(const SnackBar(content: Text('Véhicule ajouté avec succès')));
      }

      modelController.clear();
      licenseController.clear();
      if (mounted) {
        setState(() {
          selectedImageFile = null;
          selectedImageBytes = null;
          _selectedFileName = null; // مسح اسم الملف المخزن
          _isLoading = false;
        });
      }
    } on StorageException catch (e) {
      // 11. معالجة الأخطاء الخاصة بـSupabase Storage
      debugPrint('Supabase Storage Error: ${e.message}');
      if (messenger != null) {
        messenger.showSnackBar(SnackBar(content: Text('Erreur de stockage Supabase: ${e.message}')));
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // 12. معالجة الأخطاء العامة
      debugPrint('General Error during addVehicle: $e');
      if (messenger != null) {
        messenger.showSnackBar(SnackBar(content: Text('Erreur générale: ${e.toString()}')));
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un véhicule')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView( // أضف SingleChildScrollView لتجنب تجاوز الشاشة
          child: Column(
            children: [
              TextField(controller: modelController, decoration: const InputDecoration(labelText: 'Modèle')),
              const SizedBox(height: 16),
              TextField(controller: licenseController, decoration: const InputDecoration(labelText: 'Immatriculation')),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Disponible'),
                value: isAvailable,
                onChanged: (value) => setState(() => isAvailable = value),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickImage,
                child: const Text('Choisir une image'),
              ),
              const SizedBox(height: 16),
              if (selectedImageBytes != null)
                Image.memory(
                  selectedImageBytes!,
                  height: 150, // حجم مناسب للعرض
                  fit: BoxFit.contain, // احتواء الصورة بالكامل
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : addVehicle,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50), // زر بحجم كامل
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                )
                    : const Text('Ajouter', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}