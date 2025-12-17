import 'package:cta_design_prakash/screen/viewprofile_screen.dart';
import 'package:flutter/material.dart';
import '../colors/app_color.dart';

import '../models/usermodel.dart';
import '../services/api_services.dart';
import '../models/dropdownmodel.dart';
import 'navbar_screen.dart';

class ModifyProfileScreen extends StatefulWidget {
  final UserProfile initialProfile;

  const ModifyProfileScreen({super.key, required this.initialProfile});

  @override
  State<ModifyProfileScreen> createState() => _ModifyProfileScreenState();
}

class _ModifyProfileScreenState extends State<ModifyProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _userNameController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _userEmailController;
  late TextEditingController _userAltEmailController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _zipController;
  late TextEditingController _phone1Controller;
  late TextEditingController _phone2Controller;
  late TextEditingController _phone3Controller;
  late TextEditingController _p1WhatsappController;
  late TextEditingController _p2WhatsappController;
  late TextEditingController _replyToController;

  String? _selectedGender;
  String? _selectedTheme;
  int? _selectedStateId;

  List<GenderItem> _genderList = [];
  List<StateItem> _stateList = [];
  List<ThemeItem> _themeList = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = widget.initialProfile;

    _userNameController = TextEditingController(text: user.userName);
    _firstNameController = TextEditingController(text: user.firstName);
    _lastNameController = TextEditingController(text: user.lastName);
    _userEmailController = TextEditingController(text: user.userEmailId);
    _userAltEmailController = TextEditingController(text: user.userAltEmailId);
    _streetController = TextEditingController(text: user.street);
    _cityController = TextEditingController(text: user.city);
    _zipController = TextEditingController(text: user.zip);
    _phone1Controller = TextEditingController(text: user.userHomePhone);
    _phone2Controller = TextEditingController(text: user.userMobilePhone1);
    _phone3Controller = TextEditingController(text: user.userMobilePhone2);
    _p1WhatsappController = TextEditingController(text: user.p1Whatsapp ?? '');
    _p2WhatsappController = TextEditingController(text: user.p2Whatsapp ?? '');
    _replyToController = TextEditingController(text: user.replyTo);

    _selectedGender = user.gender;
    _selectedTheme = user.theme;
    _selectedStateId = user.stateId;

    _fetchDropdownData();
  }

  Future<void> _fetchDropdownData() async {
    try {
      final genders = await apiService.fetchGenderList();
      final states = await apiService.fetchStateList();
      final themes = await apiService.fetchThemeList();
      setState(() {
        _genderList = genders;
        _stateList = states;
        _themeList = themes;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching dropdown data: $e')),
      );
    }
  }

  Widget _buildTextField(
    BuildContext context,
    List<Map<String, dynamic>> fields,
  ) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.91,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white70,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fields.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                Row(
                  children: [
                    Text(
                      item['label'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    if (item['required'] == true) ...[
                      const SizedBox(width: 4),
                      const Text(
                        '*',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 6),

                // ---------- TEXT FIELD ----------
                if (item['type'] == 'text') ...[
                  TextFormField(
                    controller: item['controller'] as TextEditingController,
                    keyboardType: item['inputType'] ?? TextInputType.text,
                    validator: item['required'] == true
                        ? (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '${item['label']} is required';
                            }
                            if (item['isEmail'] == true &&
                                !RegExp(
                                  r'^[^@]+@[^@]+\.[^@]+',
                                ).hasMatch(value)) {
                              return 'Enter a valid email';
                            }
                            return null;
                          }
                        : null,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    decoration: _inputDecoration(),
                  ),
                ]
                // ---------- DROPDOWN ----------
                else if (item['type'] == 'dropdown') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.kWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black45),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton(
                        value: item['value'],
                        isExpanded: true,
                        items: item['items'],
                        onChanged: item['onChanged'],
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _validateDropdowns() {
    if (_selectedGender == null || _selectedGender!.isEmpty) {
      _showError('Gender is required');
      return false;
    }
    if (_selectedStateId == null || _selectedStateId == 0) {
      _showError('State is required');
      return false;
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.kErrorRed),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> updatedData = {
        'user_id': widget.initialProfile.userId,
        'user_name': _userNameController.text,
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'user_emailid': _userEmailController.text,
        'user_altemailid': _userAltEmailController.text,
        'gender': _selectedGender,
        'street': _streetController.text,
        'city': _cityController.text,
        'state': _selectedStateId ?? 0,
        'zip': _zipController.text,
        'user_home_phone': _phone1Controller.text,
        'user_mobile_phone1': _phone2Controller.text,
        'user_mobile_phone2': _phone3Controller.text,
        'p1_whatsapp': _p1WhatsappController.text,
        'p2_whatsapp': _p2WhatsappController.text,
        'theme_id': _themeList
            .firstWhere(
              (t) => t.theme == _selectedTheme,
              orElse: () => ThemeItem(themeId: 0, theme: 'Default'),
            )
            .themeId,
        'reply_to': _replyToController.text,
      };

      if (!_formKey.currentState!.validate()) return;
      if (!_validateDropdowns()) return;

      setState(() => _isLoading = true);

      final message = await apiService.modifyProfile(updatedData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 800));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ViewMyProfileScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFE9F0FF),
        appBar: AppBar(
          elevation: 0, // remove default shadow
          title: Text(
            'Modify My Profile',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          centerTitle: true,
          backgroundColor: AppColors.appbarblue,
          foregroundColor: Colors.white,
        ),
        drawer: NavbarScreen(),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.kDarkBlue),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18.0,
                  vertical: 20,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('Personal Details', context),
                      _buildTextField(context, [
                        {
                          'type': 'text',
                          'label': 'User Name',
                          'controller': _userNameController,
                          'required': true,
                        },
                        {
                          'type': 'text',
                          'label': 'First Name',
                          'controller': _firstNameController,
                        },
                        {
                          'type': 'text',
                          'label': 'Last Name',
                          'controller': _lastNameController,
                        },
                        {
                          'type': 'dropdown',
                          'label': 'Gender',
                          'value': _selectedGender,
                          'required': true,
                          'items': _genderList
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g.genderId,
                                  child: Text(g.gender),
                                ),
                              )
                              .toList(),
                          'onChanged': (val) =>
                              setState(() => _selectedGender = val),
                        },
                      ]),
      
                      _sectionHeader('Contact Details', context),
                      _buildTextField(context, [
                        {
                          'type': 'text',
                          'label': 'Phone 1',
                          'controller': _phone1Controller,
                          'required': true,
                        },
                        {
                          'type': 'text',
                          'label': 'Phone 2',
                          'controller': _phone2Controller,
                        },
                        {
                          'type': 'text',
                          'label': 'Phone 3',
                          'controller': _phone3Controller,
                        },
      
                        {
                          'type': 'text',
                          'label': 'Parent 1 Whatsapp Number',
                          'controller': _p1WhatsappController,
                        },
      
                        {
                          'type': 'text',
                          'label': 'Parent 2 Whatsapp Number',
                          'controller': _p2WhatsappController,
                        },
                      ]),
      
                      _sectionHeader('Email Details', context),
                      _buildTextField(context, [
                        {
                          'type': 'text',
                          'label': 'User Email',
                          'controller': _userEmailController,
                          'isEmail': true,
                          'required': true,
                        },
                        {
                          'type': 'text',
                          'label': 'Alternate Email',
                          'controller': _userAltEmailController,
                        },
                      ]),
      
                      _sectionHeader('Address Details', context),
                      _buildTextField(context, [
                        {
                          'type': 'text',
                          'label': 'Street',
                          'controller': _streetController,
                          'required': true,
                        },
                        {
                          'type': 'text',
                          'label': 'City',
                          'controller': _cityController,
                          'required': true,
                        },
                        {
                          'type': 'dropdown',
                          'label': 'State',
                          'value': _selectedStateId,
                          'required': true,
                          'items': _stateList
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.stateId,
                                  child: Text(s.stateName),
                                ),
                              )
                              .toList(),
                          'onChanged': (val) =>
                              setState(() => _selectedStateId = val),
                        },
                        {
                          'type': 'text',
                          'label': 'Zip / Postal Code',
                          'controller': _zipController,
                          'required': true,
                        },
                      ]),
                      _sectionHeader('Theme', context),
                      _buildTextField(context, [
                        {
                          'type': 'dropdown',
                          'label': 'Color Theme',
                          'value': _selectedTheme,
                          'items': _themeList
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t.theme,
                                  child: Text(t.theme),
                                ),
                              )
                              .toList(),
                          'onChanged': (val) =>
                              setState(() => _selectedTheme = val),
                        },
                      ]),
      
                      const SizedBox(height: 14),
      
                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade900,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(
                              color: AppColors.kWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _sectionHeader(String text, BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.90,
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0A3D91),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.kWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black45),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black45),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black87),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
