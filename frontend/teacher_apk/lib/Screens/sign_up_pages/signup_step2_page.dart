import 'package:flutter/material.dart';
// Note: Ensure your theme.dart, models/signup_data.dart, and services/api_service.dart
// are correctly structured and accessible for the imports to work.
import 'package:teacher_apk/theme.dart';
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

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _sections = [];
  String? _selectedDepartmentId;
  String? _selectedDesignation;

  // NEW STATE: List to store confirmed academic units
  List<AcademicUnit> _academicUnits = [];

  // Fallback data for API failure
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

  final List<String> _designations = [
    'Professor',
    'Assistant Professor',
    'Lecturer',
    'Associate Professor',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    signupData = ModalRoute.of(context)?.settings.arguments as SignupData?;
    if (_departments.isEmpty) {
      Future.microtask(() => _fetchData());
    }
  }

  // API Integration: Fetches academic data or uses fallback
  Future<void> _fetchData() async {
    if (_departments.isEmpty) {
      setState(() => _isLoading = true);
    }

    final deptSubRes = await ApiService.getDepartmentsAndSubjects();
    final sectionRes = await ApiService.getSections();

    bool apiSuccess = false;

    if (deptSubRes.statusCode == 200 && sectionRes.statusCode == 200) {
      try {
        final deptSubData = Map<String, dynamic>.from(
          jsonDecode(deptSubRes.body)['data'],
        );
        final sectionData = List<Map<String, dynamic>>.from(
          jsonDecode(sectionRes.body)['data']['sections'],
        );

        setState(() {
          _departments = List<Map<String, dynamic>>.from(
            deptSubData['departments'],
          );
          _subjects = List<Map<String, dynamic>>.from(deptSubData['subjects']);
          _sections = sectionData;
        });
        apiSuccess = true;
      } catch (e) {
        print('Error decoding academic data: $e');
      }
    }

    if (!apiSuccess || _departments.isEmpty) {
      setState(() {
        if (_departments.isEmpty) {
          _departments = _fallbackDepartments;
        }
      });
      if (mounted && deptSubRes.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to load academic data. Using extended fallback options.',
            ),
          ),
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
  Future<void> _submit() async {
    if (_selectedDepartmentId == null ||
        _selectedDesignation == null ||
        _academicUnits.isEmpty) {
      // Check against the new academic unit list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select department, designation, and add at least one section.',
          ),
        ),
      );
      return;
    }

    signupData?.designation = _selectedDesignation;

    // Compile unique IDs from the collected academic units for the API call
    signupData?.departments = _academicUnits
        .map((u) => u.departmentId)
        .toSet()
        .toList();
    signupData?.sections = _academicUnits
        .map((u) => u.sectionId)
        .toSet()
        .toList();
    signupData?.subjects = _academicUnits
        .map((u) => u.subjectId)
        .toSet()
        .toList();

    // Ensure the main selected department is included if not covered in a unit
    if (!(signupData?.departments?.contains(_selectedDepartmentId) ?? true)) {
      signupData?.departments?.add(_selectedDepartmentId!);
    }

    setState(() {
      _isSubmitting = true;
    });

    final response = await ApiService.registerTeacher(
      fullName: signupData!.fullName!,
      email: signupData!.email!,
      password: signupData!.password!,
      designation: signupData!.designation!,
      gender: signupData!.gender!,
      departments: signupData!.departments,
      subjects: signupData!.subjects,
      sections: signupData!.sections,
    );

    setState(() {
      _isSubmitting = false;
    });

    if (response.statusCode == 201) {
      if (mounted) {
        Navigator.pushNamed(
          context,
          'signupStep3',
          arguments: signupData!.email,
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ' + response.body)),
        );
      }
    }
  }

  // Method to show the new "Add Sections" dialog
  void _showAddSectionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _AddSectionsDialogContent(
          departments: _departments,
          sections: _sections,
          subjects: _subjects,
          onConfirm:
              (
                String degree,
                String year,
                String departmentId,
                String sectionId,
                String subjectId,
              ) {
                // Call the new method to add the unit
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
            value: _selectedDepartmentId,
            items: _departments.map((dept) {
              return DropdownMenuItem<String>(
                value: dept['id'].toString(),
                child: Text(dept['name']),
              );
            }).toList(),

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
          items: _designations
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
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
    required this.departments,
    required this.sections,
    required this.subjects,
    required this.onConfirm,
    super.key,
  });

  @override
  __AddSectionsDialogContentState createState() =>
      __AddSectionsDialogContentState();
}

class __AddSectionsDialogContentState extends State<_AddSectionsDialogContent> {
  // Dummy data for Degree and Year
  final List<String> _degrees = ['B.Tech', 'M.Tech', 'Ph.D'];
  final List<String> _years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];

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
    // If data is empty, use dummy values for UI testing
    List<Map<String, dynamic>> displayedData = data.isNotEmpty
        ? data
        : [
            {'id': 'dummy1', 'name': 'Dummy ${hintText} 1'},
            {'id': 'dummy2', 'name': 'Dummy ${hintText} 2'},
          ];

    return _buildDropdownContainer(
      child: DropdownButton<String>(
        isExpanded: true,
        hint: Text(hintText, style: TextStyle(color: Colors.grey[600])),
        value: currentValue,
        items: displayedData
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
    final bool canConfirm =
        _selectedDegree != null &&
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
              // Heading: Add Sections
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
              _buildStaticDropdown('Degree', _selectedDegree, _degrees, (
                value,
              ) {
                setState(() => _selectedDegree = value);
              }),

              // 2. Year Dropdown
              _buildStaticDropdown('Year', _selectedYear, _years, (value) {
                setState(() => _selectedYear = value);
              }),

              // 3. Department Dropdown
              _buildApiDataDropdown(
                'Department',
                _selectedDepartmentId,
                widget.departments,
                (value) {
                  setState(() => _selectedDepartmentId = value);
                },
              ),

              // 4. Section Dropdown
              _buildApiDataDropdown(
                'Section',
                _selectedSectionId,
                widget.sections,
                (value) {
                  setState(() => _selectedSectionId = value);
                },
              ),

              // 5. Subject Dropdown
              _buildApiDataDropdown(
                'Subject',
                _selectedSubjectId,
                widget.subjects,
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
                          // Pass all 5 selected values back to the parent
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
