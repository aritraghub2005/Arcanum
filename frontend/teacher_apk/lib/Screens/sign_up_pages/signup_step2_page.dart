import 'package:flutter/material.dart';
// Note: Ensure your theme.dart, models/signup_data.dart, and services/api_service.dart
// are correctly structured and accessible for the imports to work.
import 'package:teacher_apk/theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/signup_data.dart';
import '../../services/api_service.dart';

// =============================================================
// I. Helper Class for Academic Unit Preview
// =============================================================

class AcademicUnit {
  final String degree;
  final String year;
  final String departmentId;
  final String sectionId;
  final String subjectId;
  final String departmentName;
  final String sectionName;
  final String subjectName;

  // A unique identifier for easier removal
  final String id;

  AcademicUnit({
    required this.id,
    required this.degree,
    required this.year,
    required this.departmentId,
    required this.sectionId,
    required this.subjectId,
    required this.departmentName,
    required this.sectionName,
    required this.subjectName,
  });

  String get displayName {
    // Example: "B.Tech - 3rd Year - CSE - Section A - Java"
    return '$degree - $year - $departmentName - ${sectionName.startsWith('Section') ? sectionName : 'Section $sectionName'} - $subjectName';
  }
}

// =============================================================
// II. Sign Up Step 2 Page (Main Widget)
// =============================================================

class SignUpStep2Page extends StatefulWidget {
  const SignUpStep2Page({super.key});

  @override
  State<SignUpStep2Page> createState() => _SignUpStep2PageState();
}

class _SignUpStep2PageState extends State<SignUpStep2Page> {
  SignupData? signupData;
  bool _isLoading = false;
  bool _isSubmitting = false;

  final GlobalKey<State<DropdownButton<String>>> _departmentDropdownKey =
      GlobalKey();

  List<String> _designations = [];
  List<String> _degrees = [];
  List<String> _years = [];
  String? _selectedDepartmentId;
  String? _selectedDesignation;

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _sections = [];

  // --- ADD THIS FALLBACK LIST ---
  final List<Map<String, dynamic>> _fallbackDepartments = [
    {'id': 'fallback_cse', 'name': 'Computer Science and Engineering (CSE)'},
    {
      'id': 'fallback_ece',
      'name': 'Electronics and Communication Engineering (ECE)',
    },
    {
      'id': 'fallback_eee',
      'name': 'Electrical and Electronics Engineering (EEE)',
    },
    {'id': 'fallback_data', 'name': 'Data Science'},
    {'id': 'fallback_ai', 'name': 'Artificial Intelligence (AI)'},
    {'id': 'fallback_mech', 'name': 'Mechanical Engineering'},
    {'id': 'fallback_civil', 'name': 'Civil Engineering'},
    {'id': 'fallback_phy', 'name': 'Physics'},
    {'id': 'fallback_math', 'name': 'Mathematics'},
    {'id': 'fallback_chem', 'name': 'Chemistry'},
    {'id': 'fallback_hums', 'name': 'Humanities and Social Sciences'},
  ];

  // NEW STATE: List to store confirmed academic units
  final List<AcademicUnit> _academicUnits = [];

  // Fallback data for API failure


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    signupData = ModalRoute.of(context)?.settings.arguments as SignupData?;
    if (_departments.isEmpty) {
      Future.microtask(() => _fetchData());
    }
  }

  // API Integration: Fetches academic data or uses fallback
  // In signup_step2_page.dart

  // In _SignUpStep2PageState class

  Future<void> _fetchData() async {
    if (_departments.isEmpty) {
      setState(() => _isLoading = true);
    }

    bool apiSuccess = false;
    String errorMessage = 'Failed to load academic data. Using fallbacks.';

    try {
      // Fetch all data in parallel
      final results = await Future.wait([
        ApiService.getDepartmentsAndSubjects(),

        ApiService.getSections(year: 2027), // Or appropriate year
        // ApiService.getAcademicConfig(), // <-- ADD THIS
      ]);

      final deptSubRes = results[0] as http.Response;
      final sectionRes = results[1] as http.Response;
      // final configRes = results[2] as http.Response; // <-- GET RESULT

      if (deptSubRes.statusCode == 200 &&
          sectionRes.statusCode == 200) { // <-- CHECK ALL

        try {
          // --- Defensive parsing & logging (REPLACES the unsafe Map.from / List.from calls) ---
          Map<String, dynamic> deptSubData = {};
          List<Map<String, dynamic>> sectionData = [];

          try {
            debugPrint('DEPT_SUB_RESPONSE(status:${deptSubRes.statusCode}): ${deptSubRes.body}');
            debugPrint('SECTION_RESPONSE(status:${sectionRes.statusCode}): ${sectionRes.body}');

            // Parse dept-sub response safely
            final decodedDept = jsonDecode(deptSubRes.body);
            if (decodedDept is Map<String, dynamic>) {
              final maybeData = decodedDept['data'];
              if (maybeData is Map<String, dynamic>) {
                deptSubData = Map<String, dynamic>.from(maybeData);
              } else {
                // No data wrapper -> use top-level map, but guard null
                deptSubData = Map<String, dynamic>.from(decodedDept);
              }
            } else {
              debugPrint('Unexpected deptSubRes JSON shape: ${decodedDept.runtimeType}');
            }

            // Parse section response safely
            final decodedSection = jsonDecode(sectionRes.body);
            if (decodedSection is Map<String, dynamic>) {
              // prefer data.sections
              if (decodedSection.containsKey('data') && decodedSection['data'] is Map) {
                final ds = decodedSection['data'];
                if (ds is Map && ds['sections'] is List) {
                  sectionData = List<Map<String, dynamic>>.from(
                    (ds['sections'] as List).map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}),
                  );
                }
              }
              // fallback to top-level "sections" key
              else if (decodedSection['sections'] is List) {
                sectionData = List<Map<String, dynamic>>.from(
                  (decodedSection['sections'] as List).map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}),
                );
              }
            } else if (decodedSection is List) {
              // server returned list directly
              sectionData = List<Map<String, dynamic>>.from(
                decodedSection.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}),
              );
            } else {
              debugPrint('Unexpected sectionRes JSON shape: ${decodedSection.runtimeType}');
            }
          } catch (e, st) {
            debugPrint('Error parsing responses in _fetchData: $e\n$st');
            // leave deptSubData and sectionData empty — fallbacks below handle it
          }


          // <-- PARSE NEW CONFIG DATA -->
          // final configData = Map<String, dynamic>.from(
          //   jsonDecode(configRes.body)['data'],
          // );

          setState(() {
            _departments = (deptSubData['departments'] is List)
                ? List<Map<String, dynamic>>.from(deptSubData['departments'].map((e) => e is Map ? Map<String, dynamic>.from(e) : <String,dynamic>{}))
                : _fallbackDepartments;

            _subjects = (deptSubData['subjects'] is List)
                ? List<Map<String, dynamic>>.from(deptSubData['subjects'].map((e) => e is Map ? Map<String, dynamic>.from(e) : <String,dynamic>{}))
                : [];

            _sections = sectionData;
            // defaults
            if (_designations.isEmpty) _designations = ['Professor', 'Assistant Professor'];
            if (_degrees.isEmpty) _degrees = ['B.Tech', 'M.Tech'];
            if (_years.isEmpty) _years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];

            _selectedDepartmentId = _departments.any((d) => d['id'].toString() == (_selectedDepartmentId ?? ''))
                ? _selectedDepartmentId
                : null;

          });

          apiSuccess = true;
        } catch (e) {
          print('Error decoding academic data: $e');
          errorMessage = 'Failed to parse server data. Using fallbacks.';
        }
      } else {
        print('API Error: ${deptSubRes.statusCode} or ${sectionRes.statusCode}}');
        errorMessage = 'Server returned an error. Using fallbacks.';
      }

    } catch (e) {
      print('Network error in _fetchData: $e');
      errorMessage = 'Could not connect to server. Using fallbacks.';
    }

    if (!apiSuccess) {
      setState(() {
        if (_departments.isEmpty) {
          _departments = _fallbackDepartments;
        }
        // Use fallbacks for config data if needed
        if (_designations.isEmpty) _designations = ['Professor', 'Assistant Professor'];
        if (_degrees.isEmpty) _degrees = ['B.Tech', 'M.Tech'];
        if (_years.isEmpty) _years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  // NEW LOGIC: Adds a confirmed AcademicUnit to the list and updates the chips used for submission
  void _addAcademicUnit({
    required String degree,
    required String year,
    required String departmentId,
    required String sectionId,
    required String subjectId,
  }) {
    // Look up names for display
    final dept = (_departments.isEmpty ? _fallbackDepartments : _departments)
        .firstWhere(
          (d) => d['id'].toString() == departmentId,
          orElse: () => {'name': 'Unknown Dept'},
        );
    final section = _sections.firstWhere(
      (s) => s['id'].toString() == sectionId,
      orElse: () => {'name': 'Unknown Section'},
    );
    final subject = _subjects.firstWhere(
      (s) => s['id'].toString() == subjectId,
      orElse: () => {'name': 'Unknown Subject'},
    );

    final newUnit = AcademicUnit(
      id: UniqueKey().toString(), // Unique key for deletion
      degree: degree,
      year: year,
      departmentId: departmentId,
      sectionId: sectionId,
      subjectId: subjectId,
      departmentName: dept['name'],
      sectionName: section['name'],
      subjectName: subject['name'],
    );

    // Prevent duplicates based on Section and Subject IDs (simulating a unique assignment)
    bool isDuplicate = _academicUnits.any(
      (unit) =>
          unit.sectionId == sectionId &&
          unit.subjectId == subjectId &&
          unit.departmentId == departmentId,
    );

    if (!isDuplicate) {
      setState(() {
        _academicUnits.add(newUnit);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This section/subject combination is already added.'),
        ),
      );
    }
  }

  // API Integration: Submits registration data
  // In _SignUpStep2PageState class

  // In _SignUpStep2PageState class

  Future<void> _submit() async {
    // 1. Validation check
    if (_selectedDepartmentId == null ||
        _selectedDesignation == null ||
        _academicUnits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select department, designation, and add at least one section.',
          ),
        ),
      );
      return;
    }

    // 2. NEW: Compile data for the API structure from user.route.js
    final Set<String> departmentIds = <String>{};
    final Set<String> subjectIds = <String>{};
    final Set<String> sectionIds = <String>{};

    // Add the primary department ID
    departmentIds.add(_selectedDepartmentId!);

    // Loop over all added academic units and collect their IDs
    for (final unit in _academicUnits) {
      departmentIds.add(unit.departmentId);
      subjectIds.add(unit.subjectId);
      sectionIds.add(unit.sectionId);
    }

    // 3. Start loading
    setState(() {
      _isSubmitting = true;
    });

    http.Response? response;
    String errorMessage = 'An unknown error occurred.';

    // ==========================================================
    // UPDATED: try-catch block with correct ApiService call
    // ==========================================================
    try {
      // 4. TRY to call the API with the correct structure
      response = await ApiService.registerTeacher(
        fullName: signupData!.fullName!,
        email: signupData!.email!,
        password: signupData!.password!,
        designation: _selectedDesignation!,
        gender: signupData!.gender ?? '',
        // Pass the correct lists
        departments: departmentIds.toList(),
        subjects: subjectIds.toList(),
        sections: sectionIds.toList(),
      );

      // 5. Check the API response
      if (response.statusCode == 200 || response.statusCode == 201) {
        // SUCCESS!
        try {
          final map = jsonDecode(response.body) as Map<String, dynamic>;
          final dataMap = map['data'] as Map<String, dynamic>?;

          String? userId;
          String? token;

          if (dataMap != null) {
            userId = dataMap['teacherId']?.toString();
            token = dataMap['token']?.toString();
          } else {
            userId = map['teacherId']?.toString() ?? map['userId']?.toString();
            token = map['token']?.toString();
          }

          if (userId != null) {
            signupData!.userId = userId;

            await ApiService.saveUserLocally(
              userId: userId,
              email: signupData!.email!,
              token: token,
            );

            if (mounted) {
              Navigator.pushNamed(
                context,
                'signupStep3', // Assuming this is the OTP page
                arguments: {
                  'email': signupData!.email!,
                  'teacherId': userId, // Pass this to the OTP page
                },
              );
            }
          } else {
            errorMessage = 'Registration successful, but user ID was not found.';
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(errorMessage)),
              );
            }
          }
        } catch (e) {
          print('Error parsing registration response: $e');
          errorMessage = 'Registration successful, but response was unreadable.';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          }
        }
      } else {
        // API returned an error
        String apiError = response.body;
        try {
          final errorMap = jsonDecode(response.body) as Map<String, dynamic>;
          apiError = errorMap['message']?.toString() ?? response.body;
        } catch (e) {
          // Not a JSON error
        }
        errorMessage = 'Registration failed: $apiError';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    } catch (e) {
      // 6. CATCH any network crash
      print('Error during registration: $e');
      errorMessage =
      'Could not connect to the server. Please check your internet.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      // 7. FINALLY, stop the loading spinner
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Method to show the new "Add Sections" dialog
  // Method to show the new "Add Sections" dialog
  void _showAddSectionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _AddSectionsDialogContent(
          // --- UPDATED: Pass all the new lists ---
          degrees: _degrees,
          years: _years,
          departments: _departments,
          sections: _sections,
          subjects: _subjects,
          onConfirm: (
              String degree,
              String year,
              String departmentId,
              String sectionId,
              String subjectId,
              ) {
            _addAcademicUnit(
              degree: degree,
              year: year,
              departmentId: departmentId,
              sectionId: sectionId,
              subjectId: subjectId,
            );
          },
        );
      },
    );
  }

  // Helper methods (_buildDepartmentDropdown, _buildDesignationDropdown) unchanged for brevity

  Widget _buildDepartmentDropdown() {
    bool isDataReady = _departments.isNotEmpty;

    // --- FIX: Reset invalid selectedDepartmentId ---
    if (_selectedDepartmentId != null &&
        !_departments.any((d) => d['id'].toString() == _selectedDepartmentId)) {
      _selectedDepartmentId = null;
    }


    // Ensure value is valid
    if (_selectedDepartmentId != null &&
        !_departments.any((d) => d['id'].toString() == _selectedDepartmentId)) {
      _selectedDepartmentId = null;
    }

    return GestureDetector(
      onTap: isDataReady
          ? () {
        final dynamic state = _departmentDropdownKey.currentState;
        state?.didChangeDependencies();
      }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: !isDataReady && _isLoading
              ? Border.all(color: Colors.grey, width: 2)
              : null,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            key: _departmentDropdownKey,
            isExpanded: true,
            hint: Text(
              !isDataReady && _isLoading
                  ? 'Loading departments...'
                  : 'Choose your department',
              style: TextStyle(
                color: !isDataReady && _isLoading
                    ? Colors.grey
                    : Colors.grey[600],
              ),
            ),
            value: _selectedDepartmentId, // <-- now guaranteed valid or null
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Select a department'),
              ),
              ..._departments.map((dept) {
                return DropdownMenuItem<String>(
                  value: dept['id'].toString(),
                  child: Text(dept['name']),
                );
              }).toList(),
            ],

            onChanged: isDataReady
                ? (value) => setState(() {
              _selectedDepartmentId = value;
              _selectedDesignation = null;
            })
                : null,
          ),
        ),
      ),
    );
  }


  Widget _buildDesignationDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text('Designation', style: TextStyle(color: Colors.grey[600])),
          value: _selectedDesignation,
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Select designation'),
            ),
            ..._designations.map((e) => DropdownMenuItem(value: e, child: Text(e))),
          ],

          onChanged: (value) => setState(() => _selectedDesignation = value),
        ),
      ),
    );
  }

  // NEW WIDGET: Builds the preview chips
  Widget _buildAcademicUnitChips() {
    if (_academicUnits.isEmpty) {
      return Text(
        'No sections added yet.',
        style: TextStyle(color: Colors.grey[500]),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _academicUnits.map((unit) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                unit.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              // Delete button (clickable icon)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _academicUnits.remove(unit);
                  });
                },
                child: const Icon(Icons.close, size: 16, color: Colors.white70),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.backgroundGradientStart,
            AppTheme.backgroundGradientEnd,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // ... (Top Bar - unchanged)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: AppTheme.primaryColor,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              // ================== Form & Stepper ==================
              Expanded(
                child: Column(
                  children: [
                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Your Profile',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Academic Information',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // --- Department Dropdown Field ---
                            _buildDepartmentDropdown(),
                            const SizedBox(height: 16),

                            // --- Designation Dropdown Field ---
                            _buildDesignationDropdown(),
                            const SizedBox(height: 24),

                            // --- Add Sections Title and Button (Opens Dialog) ---
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Add sections',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.add_circle,
                                    color: AppTheme.primaryColor,
                                  ),
                                  onPressed: _showAddSectionsDialog,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // --- NEW: Display Selected Academic Units ---
                            _buildAcademicUnitChips(),

                            const SizedBox(height: 24),

                            // NOTE: The previous Section/Subject chips are removed here
                            // as their functionality is replaced by the new dialog/preview chips.
                          ],
                        ),
                      ),
                    ),

                    // Fixed bottom section for button and stepper
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32),
                                ),
                                elevation: 0,
                              ),
                              child: _isSubmitting
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Text(
                                          'Next',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Step 2 of 3',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// III. Add Sections Dialog Content (Separate Widget) - Unchanged
// -------------------------------------------------------------

class _AddSectionsDialogContent extends StatefulWidget {
  final List<String> degrees;
  final List<String> years;
  final List<Map<String, dynamic>> departments;
  final List<Map<String, dynamic>> sections;
  final List<Map<String, dynamic>> subjects;

  final Function(
    String degree,
    String year,
    String departmentId,
    String sectionId,
    String subjectId,
  )
  onConfirm;

  const _AddSectionsDialogContent({
    required this.degrees,
    required this.years,
    required this.departments,
    required this.sections,
    required this.subjects,
    required this.onConfirm,
  });

  @override
  __AddSectionsDialogContentState createState() =>
      __AddSectionsDialogContentState();
}

class __AddSectionsDialogContentState extends State<_AddSectionsDialogContent> {


  String? _selectedDegree;
  String? _selectedYear;
  String? _selectedDepartmentId;
  String? _selectedSectionId;
  String? _selectedSubjectId;

  // Helper method to build a styled dropdown container
  Widget _buildDropdownContainer({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }

  // Dropdown for Degree and Year (Static data)
  Widget _buildStaticDropdown(
    String hintText,
    String? currentValue,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return _buildDropdownContainer(
      child: DropdownButton<String>(
        isExpanded: true,
        hint: Text(hintText, style: TextStyle(color: Colors.grey[600])),
        value: currentValue,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  // Dropdown for Department, Section, Subject (API connected data structure)
  Widget _buildApiDataDropdown(
    String hintText,
    String? currentValue,
    List<Map<String, dynamic>> data,
    Function(String?) onChanged,
  ) {

    return _buildDropdownContainer(
      child: DropdownButton<String>(
        isExpanded: true,
        hint: Text(hintText, style: TextStyle(color: Colors.grey[600])),
        value: currentValue,
        items: data
            .map(
              (e) => DropdownMenuItem(
                value: e['id'].toString(),
                child: Text(e['name']),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- CASCADING FILTERS ---
// Capture non-final state fields into final locals to allow safe promotion
    final String? selectedDept = _selectedDepartmentId;
    final String? selectedYear = _selectedYear;

    // --- FIX: Ensure selected values exist in the items ---
    if (_selectedDepartmentId != null &&
        !widget.departments.any((d) => d['id'].toString() == _selectedDepartmentId)) {
      _selectedDepartmentId = null;
    }

    if (_selectedSectionId != null &&
        !widget.sections.any((s) => s['id'].toString() == _selectedSectionId)) {
      _selectedSectionId = null;
    }

    if (_selectedSubjectId != null &&
        !widget.subjects.any((s) => s['id'].toString() == _selectedSubjectId)) {
      _selectedSubjectId = null;
    }


// Optional debug (keep or remove)
    print('--- DEBUGGING FILTERS ---');
    print('Selected Department ID: $selectedDept');
    print('Selected Year: $selectedYear');
    if (widget.subjects.isNotEmpty) print('First Subject JSON: ${widget.subjects.first}');
    if (widget.sections.isNotEmpty) print('First Section JSON: ${widget.sections.first}');

// Available subjects: filter by department_id where possible, otherwise keep all
    final List<Map<String, dynamic>> availableSubjects = selectedDept != null
        ? widget.subjects.where((subject) {
      final subjDept = (subject['department_id'] ?? '').toString();
      // if we have no department mapping on subject, include it (can't decide)
      if (subjDept.isEmpty) return true;
      return subjDept == selectedDept;
    }).toList()
        : widget.subjects;

// Available sections: try to filter by department and year where possible.
    final List<Map<String, dynamic>> availableSections = widget.sections.where((section) {
      final secDept = (section['department_id'] ?? '').toString();
      // try both 'year', 'year_name', and 'batch' keys from API
      final secYear = (section['year'] ?? section['year_name'] ?? section['batch'] ?? '').toString();

      bool deptMatches = true;
      bool yearMatches = true;

      // Department match: only enforce if user selected a department and the section has a dept link
      if (selectedDept != null && secDept.isNotEmpty) {
        deptMatches = secDept == selectedDept;
      }

      // Year match: only enforce if user selected a year and the section provides a year/batch
      if (selectedYear != null && secYear.isNotEmpty) {
        // Safe to call contains because selectedYear is final and non-null here
        yearMatches = secYear == selectedYear ||
            secYear.contains(selectedYear) ||
            selectedYear.contains(secYear);
      }

      return deptMatches && yearMatches;
    }).toList();

// --- END CASCADING FILTERS ---


    final bool canConfirm = _selectedDegree != null &&
        _selectedYear != null &&
        _selectedDepartmentId != null &&
        _selectedSectionId != null &&
        _selectedSubjectId != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      backgroundColor: Colors.transparent,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.backgroundGradientStart.withOpacity(0.95),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Add Sections',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // 1. Degree Dropdown
              _buildStaticDropdown('Degree', _selectedDegree, widget.degrees, (
                  value,
                  ) {
                setState(() {
                  _selectedDegree = value;
                  _selectedYear = null; // <-- RESET CHILD
                  _selectedSectionId = null; // <-- RESET CHILD
                });
              }),

              // 2. Year Dropdown
              _buildStaticDropdown('Year', _selectedYear, widget.years, (value) {
                setState(() {
                  _selectedYear = value;
                  _selectedSectionId = null; // <-- RESET CHILD
                });
              }),

              // 3. Department Dropdown
              _buildApiDataDropdown(
                'Department',
                _selectedDepartmentId,
                widget.departments,
                    (value) {
                  setState(() {
                    _selectedDepartmentId = value;
                    _selectedSectionId = null; // <-- RESET CHILD
                    _selectedSubjectId = null; // <-- RESET CHILD
                  });
                },
              ),

              // 4. Section Dropdown
              _buildApiDataDropdown(
                'Section',
                _selectedSectionId,
                availableSections, // <-- USE FILTERED LIST
                    (value) {
                  setState(() => _selectedSectionId = value);
                },
              ),

              // 5. Subject Dropdown
              _buildApiDataDropdown(
                'Subject',
                _selectedSubjectId,
                availableSubjects, // <-- USE FILTERED LIST
                    (value) {
                  setState(() => _selectedSubjectId = value);
                },
              ),

              const SizedBox(height: 16),

              // Confirm Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: canConfirm
                      ? () {
                    widget.onConfirm(
                      _selectedDegree!,
                      _selectedYear!,
                      _selectedDepartmentId!,
                      _selectedSectionId!,
                      _selectedSubjectId!,
                    );
                    Navigator.of(context).pop();
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}