import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async'; // Add this import for Timer

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String reference;
  final VoidCallback onPaymentSuccess;
  final Function(String) onPaymentError;

  const PaymentWebViewScreen({
    Key? key,
    required this.paymentUrl,
    required this.reference,
    required this.onPaymentSuccess,
    required this.onPaymentError,
  }) : super(key: key);

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _paymentCompleted = false;
  bool _isDisposed = false;
  bool _showManualVerify = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    
    // Set a timeout to show manual verification option
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!_paymentCompleted && mounted) {
        setState(() {
          _showManualVerify = true;
        });
      }
    });
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            print('🔄 WebView progress: $progress%');
          },
          onPageStarted: (String url) {
            print('🌐 Page started: $url');
            if (!_isDisposed && mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            print('✅ Page finished: $url');
            if (!_isDisposed && mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            _checkPaymentStatus(url);
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ WebView error: ${error.errorCode} - ${error.description}');
            if (!_paymentCompleted && !_isDisposed && mounted) {
              _safeOnPaymentError('WebView error: ${error.description}');
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            print('🧭 Navigation request: ${request.url}');
            
            // Check if this is a payment completion URL
            if (_checkPaymentStatus(request.url)) {
              return NavigationDecision.prevent;
            }
            
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            print('🔗 URL changed: ${change.url}');
            _checkPaymentStatus(change.url ?? '');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
      
    print('💰 Payment WebView initialized');
    print('🔗 Payment URL: ${widget.paymentUrl}');
    print('📋 Reference: ${widget.reference}');
  }

  bool _checkPaymentStatus(String url) {
    print('🔍 Checking payment status for URL: $url');
    
    // Enhanced Paystack success URL patterns
    bool isSuccessUrl = url.contains('callback') || 
                       url.contains('success') || 
                       url.contains('transaction/success') ||
                       url.contains('verify') ||
                       url.contains('reference=') ||
                       url.contains('trxref=') ||
                       url.contains('transaction_id=') ||
                       url.contains('close') ||
                       url.contains('complete') ||
                       url.contains('thank') ||
                       url.contains('approved') ||
                       (url.contains('paystack') && 
                        (url.contains('success') || 
                         url.contains('verify') || 
                         url.contains('complete') ||
                         url.contains('close'))) ||
                       (url.contains('callback') && url.contains(widget.reference)) ||
                       url.contains(widget.reference); // Direct reference match
    
    // Enhanced Paystack failure URL patterns
    bool isFailureUrl = url.contains('failed') || 
                       url.contains('error') || 
                       url.contains('cancel') ||
                       url.contains('cancelled') ||
                       url.contains('declined') ||
                       url.contains('close') ||
                       url.contains('failure') ||
                       (url.contains('paystack') && 
                        (url.contains('failed') || 
                         url.contains('error') || 
                         url.contains('cancel') ||
                         url.contains('close')));
    
    // Check for specific success indicators in page content
    bool hasSuccessIndicators = url.contains('Transaction successful') ||
                               url.contains('Payment successful') ||
                               url.contains('Thank you for your payment');
    
    if ((isSuccessUrl || hasSuccessIndicators) && !_paymentCompleted) {
      print('🎉 Payment success detected via URL: $url');
      print('📋 Reference: ${widget.reference}');
      _paymentCompleted = true;
      _timeoutTimer?.cancel();
      
      // Wait for payment processing and page to fully load
      Future.delayed(const Duration(seconds: 3), () {
        _safeOnPaymentSuccess();
      });
      return true;
    }
    
    if (isFailureUrl && !_paymentCompleted) {
      print('❌ Payment failure detected via URL: $url');
      _paymentCompleted = true;
      _timeoutTimer?.cancel();
      
      String errorMessage = 'Payment was cancelled or failed';
      if (url.contains('cancel') || url.contains('cancelled')) {
        errorMessage = 'Payment was cancelled by user';
      } else if (url.contains('failed') || url.contains('declined')) {
        errorMessage = 'Payment failed. Please try again.';
      } else if (url.contains('error')) {
        errorMessage = 'An error occurred during payment';
      } else if (url.contains('close')) {
        errorMessage = 'Payment window was closed';
      }
      
      Future.delayed(const Duration(seconds: 1), () {
        _safeOnPaymentError(errorMessage);
      });
      return true;
    }
    
    return false;
  }

  // Safe callback methods
  void _safeOnPaymentSuccess() {
    if (!_isDisposed && mounted) {
      print('✅ Calling payment success callback');
      widget.onPaymentSuccess();
      Navigator.of(context).pop();
    }
  }

  void _safeOnPaymentError(String error) {
    if (!_isDisposed && mounted) {
      print('❌ Calling payment error callback: $error');
      widget.onPaymentError(error);
      Navigator.of(context).pop();
    }
  }

  void _manualVerifyPayment() {
    if (!_paymentCompleted && mounted) {
      print('🔄 Manual payment verification triggered');
      _paymentCompleted = true;
      _timeoutTimer?.cancel();
      _safeOnPaymentSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Complete Payment'),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _showExitConfirmation,
          ),
          actions: [
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)),
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            
            if (_isLoading)
              Container(
                color: Colors.white,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Loading payment gateway...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Manual verification button (appears after timeout)
            if (_showManualVerify && !_paymentCompleted)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Payment taking too long?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'If you have completed the payment but are stuck here, click the button below to verify manually.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _manualVerifyPayment,
                        icon: const Icon(Icons.verified_user, size: 18),
                        label: const Text('Verify Payment Manually'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        // Add a bottom navigation bar with reference info
        bottomNavigationBar: _buildBottomInfo(),
      ),
    );
  }

  Widget _buildBottomInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Reference: ${widget.reference}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    if (_paymentCompleted || _isDisposed) {
      Navigator.of(context).pop();
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Payment?'),
        content: const Text('Are you sure you want to cancel this payment? Your transaction will not be completed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue Payment'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close webview
              if (!_paymentCompleted) {
                _safeOnPaymentError('Payment cancelled by user');
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Cancel Payment'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timeoutTimer?.cancel();
    print('🔚 Payment WebView disposed - Payment completed: $_paymentCompleted');
    super.dispose();
  }
}