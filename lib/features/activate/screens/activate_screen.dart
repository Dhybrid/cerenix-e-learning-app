import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../../../core/network/api_service.dart';
import '../models/activation_models.dart';
import 'payment_webview_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  int _currentIndex = 0;
  final TextEditingController _activationController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  List<BillingPlan> _plans = [];
  bool _isLoading = true;
  bool _isActivating = false;
  bool _hasInternet = true;
  bool _hasUniversityData = false; // NEW: Track university data state
  UserActivation? _currentActivation;
  Map<String, dynamic> _userData = {};

  // Add a listener for Hive changes
  // late StreamSubscription<BoxEvent> _hiveSubscription;
  StreamSubscription<BoxEvent>? _hiveSubscription;

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
    _loadUserData();

    // Listen to Hive changes for automatic updates
    // _setupHiveListener();

    Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() {
          _hasInternet = result != ConnectivityResult.none;
        });
        if (_hasInternet && _plans.isEmpty) {
          _loadData();
        }
      }
    });
  }

  // NEW: Set up Hive listener to detect changes
  // void _setupHiveListener() async {
  //   final box = await Hive.openBox('user_box');
  //   _hiveSubscription = box.watch().listen((event) {
  //     print('🔄 Hive data changed: ${event.key}');
  //     if (event.key == 'current_user' && mounted) {
  //       print('🎯 User data updated, refreshing activation screen...');
  //       _loadUserData();
  //     }
  //   });
  // }

  // UPDATED: Set up Hive listener to detect changes
  // void _setupHiveListener() async {
  //   final box = await Hive.openBox('user_box');
  //   _hiveSubscription = box.watch().listen((event) {
  //     print('🔄 Hive data changed: ${event.key}');
  //     if (event.key == 'current_user' && mounted) {
  //       print('🎯 User data updated, forcing COMPLETE refresh...');
  //       _loadData(); // Use _loadData instead of _loadUserData to force API calls
  //     }
  //   });
  // }

  @override
  void dispose() {
    _activationController.dispose();
    _referralController.dispose();
    _scrollController.dispose();
    // _hiveSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _hasInternet = connectivityResult != ConnectivityResult.none;
    });
  }

  // UPDATED: Simplified user data loading
  Future<void> _loadUserData() async {
    try {
      print('🔄 Loading user data for activation screen...');
      await _loadData(); // Directly load data which will get user data from API
    } catch (e) {
      print('❌ Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // UPDATED: Improved data loading with better user data handling
  // Future<void> _loadData() async {
  //   if (!_hasInternet) {
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //         _plans = [];
  //         _currentActivation = null;
  //         _hasUniversityData = false;
  //       });
  //     }
  //     return;
  //   }

  //   try {
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = true;
  //       });
  //     }

  //     print('🔄 Loading activation data...');

  //     // Get fresh user data from API first
  //     final userData = await ApiService().getCurrentUser();
  //     if (userData == null) {
  //       print('❌ No user data available');
  //       if (mounted) {
  //         setState(() {
  //           _isLoading = false;
  //           _plans = [];
  //           _currentActivation = null;
  //           _hasUniversityData = false;
  //         });
  //       }
  //       return;
  //     }

  //     // Store user data for reference
  //     _userData = userData;
  //     print('📱 User data loaded: ${userData['email']}');

  //     // Extract university ID with the fresh user data
  //     String? universityId = _extractUniversityId(userData);

  //     // UPDATE: Set the university data flag
  //     _hasUniversityData = universityId != null && universityId.isNotEmpty;

  //     if (_hasUniversityData) {
  //       print('🎓 Loading billing plans for university: $universityId');
  //       try {
  //         _plans = await ApiService().getBillingPlans(universityId!);
  //         print('📦 Loaded ${_plans.length} billing plans');
  //       } catch (e) {
  //         print('❌ Error loading billing plans: $e');
  //         _plans = [];
  //       }
  //     } else {
  //       print('⚠️ No university ID available, showing empty plans');
  //       _plans = [];
  //     }

  //     // Load activation status
  //     await _loadActivationStatus();

  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     }
  //   } catch (e) {
  //     print('❌ Error loading data: $e');
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //         _plans = [];
  //         _currentActivation = null;
  //         _hasUniversityData = false;
  //       });
  //     }
  //   }
  // }

  // UPDATED: Improved data loading with FRESH API data
  // FIXED: Simple data loading without infinite loops
  Future<void> _loadData() async {
    if (!_hasInternet) {
      setState(() {
        _isLoading = false;
        _plans = [];
        _currentActivation = null;
        _hasUniversityData = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      print('🔄 Loading activation data...');

      // FIX: Get user data AND force update to get complete university data
      final userData = await ApiService().getCurrentUser();
      if (userData == null) {
        print('❌ No user data available');
        setState(() {
          _isLoading = false;
          _plans = [];
          _currentActivation = null;
          _hasUniversityData = false;
        });
        return;
      }

      // FIX: If user has onboarding completed but no university data in Hive,
      // force update profile to get complete data from backend
      if (userData['onboarding_completed'] == true &&
          (userData['university'] == null ||
              userData['university_id'] == null)) {
        print(
          '🔄 User completed onboarding but missing university data, forcing profile update...',
        );

        try {
          await ApiService().updateProfile(
            userId: userData['id'],
            email: userData['email'],
            name: userData['name'] ?? '',
            bio: userData['bio'] ?? '',
            phone: userData['phone'] ?? '',
            location: userData['location'] ?? '',
          );

          // Get the updated user data
          final updatedUserData = await ApiService().getCurrentUser();
          if (updatedUserData != null) {
            _userData = updatedUserData;
            print('✅ Got updated user data with university info');
          } else {
            _userData = userData;
          }
        } catch (e) {
          print('⚠️ Profile update failed, using existing data: $e');
          _userData = userData;
        }
      } else {
        _userData = userData;
      }

      print('📱 User data: ${_userData['email']}');

      // Extract university ID
      String? universityId = _extractUniversityId(_userData);

      _hasUniversityData = universityId != null && universityId.isNotEmpty;

      if (_hasUniversityData) {
        print('🎓 Loading billing plans for university: $universityId');
        try {
          _plans = await ApiService().getBillingPlans(universityId!);
          print('📦 Loaded ${_plans.length} billing plans');
        } catch (e) {
          print('❌ Error loading billing plans: $e');
          _plans = [];
        }
      } else {
        print('⚠️ No university ID available');
        print(
          '🔍 User onboarding status: ${_userData['onboarding_completed']}',
        );
        print('🔍 University data: ${_userData['university']}');
        print('🔍 University ID: ${_userData['university_id']}');
        _plans = [];
      }

      // Load activation status
      await _loadActivationStatus();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading data: $e');
      setState(() {
        _isLoading = false;
        _plans = [];
        _currentActivation = null;
        _hasUniversityData = false;
      });
    }
  }

  // NEW: Method to force fresh user data from backend
  Future<Map<String, dynamic>?> _getFreshUserData() async {
    try {
      print('🔄 Getting FRESH user data from backend...');

      // Get current user to extract user ID
      final currentUser = await ApiService().getCurrentUser();
      if (currentUser == null) {
        print('❌ No current user found');
        return null;
      }

      final userId = currentUser['id'];
      final email = currentUser['email'];

      if (userId == null || email == null) {
        print('❌ Missing user ID or email');
        return null;
      }

      // Force update profile to get fresh data from backend
      await ApiService().updateProfile(
        userId: userId,
        email: email,
        name: currentUser['name'] ?? '',
        bio: currentUser['bio'] ?? '',
        phone: currentUser['phone'] ?? '',
        location: currentUser['location'] ?? '',
      );

      // Now get the fresh updated data
      final freshUserData = await ApiService().getCurrentUser();
      print('✅ Got fresh user data from backend');

      return freshUserData;
    } catch (e) {
      print('❌ Error getting fresh user data: $e');
      // Fallback to current Hive data
      return await ApiService().getCurrentUser();
    }
  }

  // UPDATED: Extract university ID from user data parameter
  String? _extractUniversityId(Map<String, dynamic> userData) {
    try {
      // Check if we have onboarding data with university_id
      if (userData['onboarding_completed'] == true) {
        print('✅ User has completed onboarding');

        // Check multiple possible locations for university data
        if (userData['university'] is Map &&
            userData['university']?['id'] != null) {
          final id = userData['university']?['id']?.toString();
          print('🎓 Found university ID in university field: $id');
          return id;
        }

        if (userData['university_id'] != null) {
          final id = userData['university_id']?.toString();
          print('🎓 Found university ID in university_id field: $id');
          return id;
        }

        // Check if we have academic data from onboarding
        if (userData['level'] != null || userData['department'] != null) {
          print(
            '📚 User has academic data but no university ID found in standard fields',
          );

          // Try to get university ID from the onboarding API
          return _getUniversityIdFromOnboardingData(userData);
        }
      } else {
        print('❌ User has not completed onboarding');
      }

      return null;
    } catch (e) {
      print('❌ Error extracting university ID: $e');
      return null;
    }
  }

  // UPDATED: Accept userData parameter
  String? _getUniversityIdFromOnboardingData(Map<String, dynamic> userData) {
    if (userData['onboarding_data'] is Map) {
      final onboardingData = userData['onboarding_data'] as Map;
      if (onboardingData['university_id'] != null) {
        return onboardingData['university_id']?.toString();
      }
    }

    // If we have academic fields but no university ID, trigger refresh
    print('🔄 No university ID found, user may need to refresh profile');
    return null;
  }

  // UPDATED: Improved activation status loading
  Future<void> _loadActivationStatus() async {
    try {
      print('📊 Getting activation status...');

      _currentActivation = await ApiService().getActivationStatus();

      if (_currentActivation != null) {
        print(
          '✅ Loaded activation status: ${_currentActivation!.grade} - Valid: ${_currentActivation!.isValid}',
        );
      } else {
        print('ℹ️ No active activation found');
      }
    } catch (e) {
      print('❌ Error loading activation status: $e');
      _currentActivation = null;
    }
  }

  void _activateWithCode() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasInternet) {
      _showErrorDialog(
        'No internet connection. Please check your connection and try again.',
      );
      return;
    }

    // Check if user has university data
    if (!_hasUniversityData) {
      _showErrorDialog(
        'University information required. '
        'Please complete your academic profile setup before activating your account.',
      );
      return;
    }

    setState(() {
      _isActivating = true;
    });

    try {
      print('🔑 Starting PIN activation...');
      final response = await ApiService().activateWithPin(
        activationCode: _activationController.text.trim(),
        referralCode: _referralController.text.trim().isNotEmpty
            ? _referralController.text.trim()
            : null,
      );

      if (response.success) {
        print('✅ PIN activation successful');
        _showSuccessDialog(
          response.message,
          response.referralApplied
              ? '🎉 +10 NTY referral credit applied!'
              : null,
        );
        _activationController.clear();
        _referralController.clear();
        await _loadData(); // Refresh data after activation
      }
    } catch (e) {
      print('❌ PIN activation error: $e');
      _showErrorDialog(
        'Activation failed, check your connection and try again',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActivating = false;
        });
      }
    }
  }

  // void _selectPlan(BillingPlan plan) {
  //   if (!plan.isClickable) {
  //     _showErrorDialog('This plan is not currently available for activation.');
  //     return;
  //   }

  //   if (!_hasInternet) {
  //     _showErrorDialog('No internet connection. Please check your connection and try again.');
  //     return;
  //   }

  //   // Check if user has university data
  //   if (!_hasUniversityData) {
  //     _showErrorDialog(
  //       'University information required. '
  //       'Please complete your academic profile setup before purchasing a plan.'
  //     );
  //     return;
  //   }

  //   final referralController = TextEditingController();

  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: const Text('Confirm Plan Selection'),
  //         content: SingleChildScrollView(
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text('Plan: ${plan.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
  //               Text('Price: ₦${plan.price.toStringAsFixed(2)}'),
  //               Text('Duration: ${plan.durationDisplay}'),
  //               Text('Grade: ${plan.grade.toUpperCase()}'),
  //               const SizedBox(height: 16),
  //               TextFormField(
  //                 controller: referralController,
  //                 decoration: const InputDecoration(
  //                   labelText: 'Referral Code (Optional)',
  //                   border: OutlineInputBorder(),
  //                   hintText: 'Enter referral code for +10 NTY',
  //                 ),
  //                 textCapitalization: TextCapitalization.characters,
  //                 validator: (value) {
  //                   if (value != null && value.isNotEmpty) {
  //                     if (value.length != 8) {
  //                       return 'Referral code must be 8 characters';
  //                     }
  //                     if (!RegExp(r'^[A-Z0-9]+$').hasMatch(value)) {
  //                       return 'Referral code must contain only uppercase letters and numbers';
  //                     }
  //                   }
  //                   return null;
  //                 },
  //               ),
  //               const SizedBox(height: 8),
  //               Text(
  //                 'If you use a referral code, the referrer will get 10 NTY credit!',
  //                 style: TextStyle(color: Colors.grey[600], fontSize: 12),
  //               ),
  //             ],
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               referralController.dispose();
  //               Navigator.pop(context);
  //             },
  //             child: const Text('Cancel'),
  //           ),
  //           ElevatedButton(
  //             onPressed: () {
  //               final referralCode = referralController.text.trim().toUpperCase();
  //               if (referralCode.isNotEmpty) {
  //                 if (referralCode.length != 8 || !RegExp(r'^[A-Z0-9]+$').hasMatch(referralCode)) {
  //                   _showErrorDialog('Invalid referral code format. Must be 8 uppercase letters/numbers.');
  //                   return;
  //                 }
  //               }

  //               referralController.dispose();
  //               Navigator.pop(context);
  //               _initiatePayment(plan, referralCode.isNotEmpty ? referralCode : null);
  //             },
  //             child: const Text('Proceed to Payment'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  void _selectPlan(BillingPlan plan) {
    if (!plan.isClickable) {
      _showErrorDialog('This plan is not currently available for activation.');
      return;
    }

    if (!_hasInternet) {
      _showErrorDialog(
        'No internet connection. Please check your connection and try again.',
      );
      return;
    }

    // Check if user has university data
    if (!_hasUniversityData) {
      _showErrorDialog(
        'University information required. '
        'Please complete your academic profile setup before purchasing a plan.',
      );
      return;
    }

    final referralController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Plan Selection'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan: ${plan.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Price: ₦${plan.price.toStringAsFixed(2)}'),
                Text('Duration: ${plan.durationDisplay}'),
                Text('Grade: ${plan.grade.toUpperCase()}'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: referralController,
                  decoration: const InputDecoration(
                    labelText: 'Referral Code (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Enter referral code for +10 NTY',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (value.length != 8) {
                        return 'Referral code must be 8 characters';
                      }
                      if (!RegExp(r'^[A-Z0-9]+$').hasMatch(value)) {
                        return 'Referral code must contain only uppercase letters and numbers';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'If you use a referral code, the referrer will get 10 NTY credit!',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // REMOVED: referralController.dispose();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final referralCode = referralController.text
                    .trim()
                    .toUpperCase();
                if (referralCode.isNotEmpty) {
                  if (referralCode.length != 8 ||
                      !RegExp(r'^[A-Z0-9]+$').hasMatch(referralCode)) {
                    _showErrorDialog(
                      'Invalid referral code format. Must be 8 uppercase letters/numbers.',
                    );
                    return;
                  }
                }

                Navigator.pop(context);
                _initiatePayment(
                  plan,
                  referralCode.isNotEmpty ? referralCode : null,
                );
                // REMOVED: referralController.dispose();
              },
              child: const Text('Proceed to Payment'),
            ),
          ],
        );
      },
    );
  }
  // ////

  void _initiatePayment(BillingPlan plan, String? referralCode) async {
    if (!mounted) return;

    setState(() {
      _isActivating = true;
    });

    try {
      print('💳 Initiating payment for plan: ${plan.name}');
      print('📋 Plan ID: ${plan.id}');
      print('🎁 Referral Code: $referralCode');

      final response = await ApiService().initiatePayment(
        planId: plan.id,
        referralCode: referralCode,
      );

      if (response.success) {
        print('✅ Payment initiated successfully');
        print('🔗 Authorization URL: ${response.authorizationUrl}');
        print('📋 Reference: ${response.reference}');

        if (mounted) {
          setState(() {
            _isActivating = false;
          });
        }

        _openPaymentWebView(response.authorizationUrl, response.reference);
      }
    } catch (e) {
      print('❌ Payment initiation error: $e');
      if (mounted) {
        if (e.toString().contains('already have an active activation')) {
          _showErrorDialog(
            'You already have an active activation for this session. '
            'You cannot purchase another plan until your current activation expires.',
          );
          await _loadData();
        } else {
          _showErrorDialog('Payment initiation failed, check your connection');
        }
        setState(() {
          _isActivating = false;
        });
      }
    }
  }

  void _openPaymentWebView(String url, String reference) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentWebViewScreen(
          paymentUrl: url,
          reference: reference,
          onPaymentSuccess: () {
            _handlePaymentSuccess(reference);
          },
          onPaymentError: (error) {
            if (mounted) {
              _showErrorDialog(
                'Payment failed, so sorry, check your network and try again',
              );
              setState(() {
                _isActivating = false;
              });
            }
          },
        ),
      ),
    );
  }

  void _handlePaymentSuccess(String reference) async {
    if (!mounted) return;

    if (mounted) {
      setState(() {
        _isActivating = true;
      });
    }

    try {
      print('🔍 Verifying payment with reference: $reference');

      await Future.delayed(const Duration(seconds: 2));

      final response = await ApiService().verifyPayment(reference);

      if (response.success) {
        print('✅ Payment verification successful');

        if (mounted) {
          _showPaymentSuccessDialog(
            response.message,
            response.referralApplied
                ? '🎉 +10 NTY referral credit applied!'
                : null,
            response.grade,
          );
        }

        _referralController.clear();
        await _loadData(); // Refresh data after payment
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      print('❌ Payment verification error: $e');
      if (mounted) {
        _showErrorDialog('Payment verification failed, check your network');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActivating = false;
        });
      }
    }
  }

  void _showSuccessDialog(String message, [String? bonusMessage]) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (bonusMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                bonusMessage,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPaymentSuccessDialog(
    String message, [
    String? bonusMessage,
    String? grade,
  ]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 8),
            Text('Payment Successful!', style: TextStyle(fontSize: 15)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 16)),
            if (bonusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                bonusMessage,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
            if (grade != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Text(
                  '🎉 You now have ${grade.toUpperCase()} access!',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                setState(() {
                  _isActivating = false;
                });
              }
            },
            child: const Text('OK', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildUniversityWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Text(
                'Academic Profile Required',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Please complete your academic profile setup with university information to view and purchase available billing plans.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/update_level').then((_) {
                  // Refresh data when returning from profile update
                  _loadData();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Complete Academic Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoInternetWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No Internet Connection',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please check your internet connection and try again',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _checkInternetConnection();
                if (_hasInternet) {
                  _loadData();
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading activation data...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: Colors.black54,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Activate Account',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          // ADD: Refresh button in app bar
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.blue),
              onPressed: _loadData,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: SafeArea(
          child: !_hasInternet
              ? _buildNoInternetWidget()
              : _isLoading
              ? _buildLoadingWidget()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show university warning if no university ID
                      if (!_hasUniversityData) ...[
                        _buildUniversityWarning(),
                        const SizedBox(height: 20),
                      ],

                      if (_currentActivation != null) ...[
                        _buildActivationStatusCard(),
                        const SizedBox(height: 20),
                      ],

                      _buildTabSelection(),

                      const SizedBox(height: 30),

                      if (_currentIndex == 0) ...[
                        _buildActivationSection(),
                      ] else ...[
                        _buildBillingSection(),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildActivationStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _currentActivation!.isValid
            ? Colors.green[50]
            : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _currentActivation!.isValid ? Colors.green : Colors.orange,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _currentActivation!.isValid ? Icons.verified : Icons.warning,
                color: _currentActivation!.isValid
                    ? Colors.green
                    : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                _currentActivation!.isValid
                    ? 'Active Subscription'
                    : 'Subscription Status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _currentActivation!.isValid
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Grade: ${_currentActivation!.grade.toUpperCase()}'),
          Text('University: ${_currentActivation!.universityName}'),
          Text('Session: ${_currentActivation!.sessionName}'),
          if (_currentActivation!.duration != null)
            Text(
              'Duration: ${_currentActivation!.duration!.replaceAll('_', ' ').toUpperCase()}',
            ),
          Text(
            'Status: ${_currentActivation!.isValid ? "Active" : "Inactive"}',
            style: TextStyle(
              color: _currentActivation!.isValid ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelection() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentIndex = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  gradient: _currentIndex == 0
                      ? const LinearGradient(
                          colors: [Colors.blue, Colors.lightBlue],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  color: _currentIndex == 0 ? null : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    'Activation Code',
                    style: TextStyle(
                      color: _currentIndex == 0 ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentIndex = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  gradient: _currentIndex == 1
                      ? const LinearGradient(
                          colors: [Colors.purple, Colors.pink],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  color: _currentIndex == 1 ? null : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    'Billing Plans',
                    style: TextStyle(
                      color: _currentIndex == 1 ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.vpn_key_rounded,
                    color: Colors.blue.shade700,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Activate with Code',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Enter your 16-digit activation code to unlock full access to all Cerenix AI features. '
                'Your code should have been provided during purchase. Each code can only be used once.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Activation Code',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _activationController,
                decoration: InputDecoration(
                  hintText: 'XXXX-XXXX-XXXX-XXXX',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter activation code';
                  }
                  final cleanCode = value.replaceAll('-', '');
                  if (cleanCode.length != 16) {
                    return 'Code must be 16 characters';
                  }
                  if (!RegExp(r'^[0-9]+$').hasMatch(cleanCode)) {
                    return 'Code must contain only numbers';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Referral Code (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _referralController,
                decoration: InputDecoration(
                  hintText: 'Enter referral code for +10 NTY',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Using a referral code will credit 10 NTY to the referrer!',
                style: TextStyle(color: Colors.green[600], fontSize: 12),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isActivating ? null : _activateWithCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    shadowColor: Colors.blue.shade200,
                  ),
                  child: _isActivating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Activate Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBillingSection() {
    final displayPlans = _plans;

    print('🎯 Building billing section with ${displayPlans.length} plans');

    if (displayPlans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.credit_card_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No billing plans available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Please check back later or contact support',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: Colors.purple.shade700,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Choose Your Plan',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Select the perfect plan for your needs. All plans include full access to Cerenix AI '
                'with premium features and dedicated support. Plans are specific to your university and current session.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        SizedBox(
          height: 520,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: displayPlans.length,
            itemBuilder: (context, index) {
              final plan = displayPlans[index];
              final isActive = plan.isClickable;

              return Container(
                width: 320,
                margin: EdgeInsets.only(
                  left: index == 0 ? 0 : 16,
                  right: index == displayPlans.length - 1 ? 0 : 16,
                ),
                child: _buildPlanCard(plan, isActive),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(BillingPlan plan, bool isActive) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: plan.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: plan.gradientColors[0].withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: plan.textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan.durationDisplay,
                          style: TextStyle(
                            fontSize: 14,
                            color: plan.textColor.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: isActive
                              ? Colors.green.withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      isActive ? 'ACTIVE' : 'INACTIVE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₦${plan.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: plan.textColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'per ${plan.duration.replaceAll('_', ' ').toLowerCase()}',
                      style: TextStyle(
                        fontSize: 14,
                        color: plan.textColor.withOpacity(0.7),
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              if (plan.features.isNotEmpty) ...[
                Text(
                  'Features:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: plan.textColor,
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: plan.features.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _getFeatureIcon(plan.features[index]),
                              size: 18,
                              color: plan.textColor.withOpacity(0.9),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                plan.features[index],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: plan.textColor.withOpacity(0.9),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isActive ? () => _selectPlan(plan) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: plan.buttonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    shadowColor: plan.buttonColor.withOpacity(0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isActive ? 'Select Plan' : 'Currently Inactive',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFeatureIcon(String feature) {
    final lowerFeature = feature.toLowerCase();

    if (lowerFeature.contains('access') || lowerFeature.contains('unlimited')) {
      return Icons.all_inclusive;
    } else if (lowerFeature.contains('support') ||
        lowerFeature.contains('help')) {
      return Icons.support_agent;
    } else if (lowerFeature.contains('ai') || lowerFeature.contains('chat')) {
      return Icons.smart_toy;
    } else if (lowerFeature.contains('download') ||
        lowerFeature.contains('export')) {
      return Icons.download;
    } else if (lowerFeature.contains('priority') ||
        lowerFeature.contains('premium')) {
      return Icons.star;
    } else if (lowerFeature.contains('storage') ||
        lowerFeature.contains('cloud')) {
      return Icons.cloud;
    } else if (lowerFeature.contains('feature') ||
        lowerFeature.contains('advanced')) {
      return Icons.bolt;
    } else if (lowerFeature.contains('update') ||
        lowerFeature.contains('latest')) {
      return Icons.update;
    } else if (lowerFeature.contains('security') ||
        lowerFeature.contains('safe')) {
      return Icons.security;
    } else if (lowerFeature.contains('mobile') ||
        lowerFeature.contains('app')) {
      return Icons.phone_iphone;
    } else if (lowerFeature.contains('web') ||
        lowerFeature.contains('browser')) {
      return Icons.web;
    }

    return Icons.check_circle;
  }
}
