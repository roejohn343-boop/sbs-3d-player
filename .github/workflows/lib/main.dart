import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const SBSPlayerApp());
}

class SBSPlayerApp extends StatelessWidget {
  const SBSPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SBS 3D Player Native',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const SBSPlayerHome(),
    );
  }
}

class SBSPlayerHome extends StatefulWidget {
  const SBSPlayerHome({super.key});

  @override
  State<SBSPlayerHome> createState() => _SBSPlayerHomeState();
}

class _SBSPlayerHomeState extends State<SBSPlayerHome> {
  VideoPlayerController? _controller;
  double _borderPadding = 38.0;
  bool _isLocked = false;
  bool _showUI = true;
  Timer? _hideTimer;
  double _playbackSpeed = 1.0;

  @override
  void dispose() {
    _controller?.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller != null && _controller!.value.isPlaying) {
        setState(() {
          _showUI = false;
        });
      }
    });
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      _controller?.dispose();
      
      _controller = VideoPlayerController.file(file)
        ..initialize().then((_) {
          setState(() {});
          _controller!.play();
          _controller!.setLooping(true);
          _startHideTimer();
        });
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
        _startHideTimer();
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (_isLocked) return;
          setState(() {
            _showUI = !_showUI;
          });
          if (_showUI) _startHideTimer();
        },
        child: Stack(
          children: [
            // Video Renderer (SBS)
            Center(
              child: _controller != null && _controller!.value.isInitialized
                  ? Row(
                      children: [
                        SizedBox(width: _borderPadding),
                        Expanded(child: _buildVideoView()),
                        Expanded(child: _buildVideoView()),
                        SizedBox(width: _borderPadding),
                      ],
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_library, size: 64, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("ভিডিও নির্বাচন করতে ওপরের বাটনে ট্যাপ করুন",
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
            ),

            // Lock Badge
            if (_isLocked)
              Positioned(
                top: 20,
                left: 20,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.8),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _isLocked = false;
                      _showUI = true;
                    });
                    _startHideTimer();
                  },
                  icon: const Icon(Icons.lock, size: 16),
                  label: const Text("স্ক্রিন আনলক করুন"),
                ),
              ),

            // UI Overlay
            if (_showUI && !_isLocked) ...[
              // Top Bar
              Positioned(
                top: 10,
                left: 15,
                right: 15,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.folder_open),
                      label: const Text("ভিডিও বাছুন"),
                    ),
                    Row(
                      children: [
                        const Text("Border: ", style: TextStyle(color: Colors.white, fontSize: 12)),
                        Slider(
                          value: _borderPadding,
                          min: 0,
                          max: 120,
                          onChanged: (val) {
                            setState(() {
                              _borderPadding = val;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.lock_outline, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _isLocked = true;
                              _showUI = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom Bar
              if (_controller != null && _controller!.value.isInitialized)
                Positioned(
                  bottom: 10,
                  left: 15,
                  right: 15,
                  child: Column(
                    children: [
                      ValueListenableBuilder(
                        valueListenable: _controller!,
                        builder: (context, VideoPlayerValue value, child) {
                          final current = value.position;
                          final total = value.duration;
                          return Row(
                            children: [
                              Text(_formatDuration(current), style: const TextStyle(color: Colors.white, fontSize: 12)),
                              Expanded(
                                child: Slider(
                                  value: current.inMilliseconds.toDouble().clamp(0.0, total.inMilliseconds.toDouble()),
                                  min: 0.0,
                                  max: total.inMilliseconds.toDouble(),
                                  onChanged: (val) {
                                    _controller!.seekTo(Duration(milliseconds: val.toInt()));
                                  },
                                ),
                              ),
                              Text(_formatDuration(total), style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          );
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            iconSize: 36,
                            icon: Icon(_controller!.value.isPlaying ? Icons.pause_circle : Icons.play_circle, color: Colors.white),
                            onPressed: _togglePlayPause,
                          ),
                          DropdownButton<double>(
                            value: _playbackSpeed,
                            dropdownColor: Colors.black87,
                            items: [0.5, 1.0, 1.25, 1.5, 2.0].map((speed) {
                              return DropdownMenuItem(
                                value: speed,
                                child: Text('${speed}x Speed', style: const TextStyle(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: (speed) {
                              if (speed != null) {
                                setState(() {
                                  _playbackSpeed = speed;
                                  _controller!.setPlaybackSpeed(speed);
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVideoView() {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}
