import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';

class AttendanceScannerScreen extends StatefulWidget {
  const AttendanceScannerScreen({super.key});
  static const routeName = '/attendance-scanner';

  @override
  State<AttendanceScannerScreen> createState() => _AttendanceScannerScreenState();
}

class _AttendanceScannerScreenState extends State<AttendanceScannerScreen> {
  MobileScannerController? _controller;
  bool _isProcessing = false;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _hasScanned) return;
    
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });

    final auth = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    final user = auth.user;

    if (user == null) {
      _showResult(false, 'User not logged in');
      return;
    }

    final result = await attendanceProvider.processAttendanceQr(
      barcode!.rawValue!,
      user.id,
      user.fullName,
    );

    if (mounted) {
      _showResult(result['success'] as bool, result['message'] as String);
    }
  }

  void _showResult(bool success, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              size: 64,
              color: success ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              success ? 'Success!' : 'Error',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.albertSans(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: success ? Colors.green : const Color(0xFF2196F3),
            ),
            child: Text(success ? 'Done' : 'Try Again', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).then((_) {
      if (!success) {
        setState(() {
          _isProcessing = false;
          _hasScanned = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white24,
              ),
              child: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
            ),
            child: Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF2196F3), width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          // Cutout for scanner area
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 280,
                height: 280,
                color: Colors.transparent,
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'Point camera at QR code',
                    style: GoogleFonts.albertSans(color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isProcessing)
                  const CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
          // Corner decorations
          _buildCornerDecoration(top: 0, left: 0, alignment: Alignment.topLeft),
          _buildCornerDecoration(top: 0, right: 0, alignment: Alignment.topRight),
          _buildCornerDecoration(bottom: 0, left: 0, alignment: Alignment.bottomLeft),
          _buildCornerDecoration(bottom: 0, right: 0, alignment: Alignment.bottomRight),
        ],
      ),
    );
  }

  Widget _buildCornerDecoration({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required Alignment alignment,
  }) {
    return Positioned(
      top: top != null ? MediaQuery.of(context).size.height / 2 - 140 + top : null,
      bottom: bottom != null ? MediaQuery.of(context).size.height / 2 - 140 + bottom : null,
      left: left != null ? MediaQuery.of(context).size.width / 2 - 140 + left : null,
      right: right != null ? MediaQuery.of(context).size.width / 2 - 140 + right : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight
                ? const BorderSide(color: Color(0xFF2196F3), width: 4)
                : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight
                ? const BorderSide(color: Color(0xFF2196F3), width: 4)
                : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
                ? const BorderSide(color: Color(0xFF2196F3), width: 4)
                : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight
                ? const BorderSide(color: Color(0xFF2196F3), width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
