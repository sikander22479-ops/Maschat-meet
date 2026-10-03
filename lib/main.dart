import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

const String appId = "62fba7a8c9e54c1dbf9c53cecc575343";

void main() {
  runApp(const MaschatApp());
}

class MaschatApp extends StatelessWidget {
  const MaschatApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maschat Meet - Live Production',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
      ),
      home: const MaschatHomeSetup(),
    );
  }
}

class MaschatHomeSetup extends StatefulWidget {
  const MaschatHomeSetup({Key? key}) : super(key: key);

  @override
  State<MaschatHomeSetup> createState() => _MaschatHomeSetupState();
}

class _MaschatHomeSetupState extends State<MaschatHomeSetup> {
  final TextEditingController _channelController = TextEditingController(text: "maschat_room_1");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maschat Meet (Zoom Style Live)'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.video_call, size: 80, color: Colors.purple),
                const SizedBox(height: 20),
                const Text(
                  'अपनी मीटिंग रूम आईडी दर्ज करें और दोस्तों को जोड़ें',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _channelController,
                  decoration: const InputDecoration(
                    labelText: 'Channel Name (मीटिंग रूम का नाम)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.meeting_room),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_channelController.text.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MaschatLiveCallScreen(
                              channelName: _channelController.text.trim(),
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('मीटिंग शुरू करें (Join Meet)', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MaschatLiveCallScreen extends StatefulWidget {
  final String channelName;
  const MaschatLiveCallScreen({Key? key, required this.channelName}) : super(key: key);

  @override
  State<MaschatLiveCallScreen> createState() => _MaschatLiveCallScreenState();
}

class _MaschatLiveCallScreenState extends State<MaschatLiveCallScreen> {
  int? _remoteUid;
  bool _localUserJoined = false;
  late RtcEngine _engine;
  bool _muted = false;
  bool _videoOff = false;

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() {
            _localUserJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          setState(() {
            _remoteUid = null;
          });
        },
      ),
    );

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.enableVideo();
    await _engine.startPreview();

    await _engine.joinChannel(
      token: "",
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Room: ${widget.channelName}'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _remoteVideo(),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                width: 120,
                height: 160,
                child: _localUserJoined && !_videoOff
                    ? AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                )
                    : Container(
                  color: Colors.grey[800],
                  child: const Center(
                    child: Text('Camera Off', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: Colors.black54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    heroTag: "mute",
                    backgroundColor: _muted ? Colors.red : Colors.white,
                    onPressed: () {
                      setState(() {
                        _muted = !_muted;
                      });
                      _engine.muteLocalAudioStream(_muted);
                    },
                    child: Icon(_muted ? Icons.mic_off : Icons.mic, color: _muted ? Colors.white : Colors.black),
                  ),
                  FloatingActionButton(
                    heroTag: "call_end",
                    backgroundColor: Colors.red,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                  FloatingActionButton(
                    heroTag: "video_toggle",
                    backgroundColor: _videoOff ? Colors.red : Colors.white,
                    onPressed: () {
                      setState(() {
                        _videoOff = !_videoOff;
                      });
                      _engine.muteLocalVideoStream(_videoOff);
                    },
                    child: Icon(_videoOff ? Icons.videocam_off : Icons.videocam, color: _videoOff ? Colors.white : Colors.black),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _remoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    } else {
      return const Center(
        child: Text(
          'मीटिंग लाइव है!\nदूसरे नेटवर्कर के जुड़ने का इंतज़ार है...',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.white70),
        ),
      );
    }
  }
}