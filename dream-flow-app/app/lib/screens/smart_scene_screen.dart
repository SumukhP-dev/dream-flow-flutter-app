import 'package:flutter/material.dart';

import '../services/smart_home_service.dart';

class SmartSceneScreen extends StatefulWidget {
  const SmartSceneScreen({super.key});

  @override
  State<SmartSceneScreen> createState() => _SmartSceneScreenState();
}

class _SmartSceneScreenState extends State<SmartSceneScreen> {
  final SmartHomeService _smartHomeService = SmartHomeService();
  List<SmartScene> _scenes = const [];
  List<SmartDevice> _devices = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final scenes = await _smartHomeService.getScenes();
    final devices = await _smartHomeService.getDevices();
    if (!mounted) return;
    setState(() {
      _scenes = scenes;
      _devices = devices;
      _isLoading = false;
    });
  }

  Future<void> _triggerScene(SmartScene scene) async {
    await _smartHomeService.triggerScene(scene.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Scene "${scene.name}" orchestrated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Scenes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildConnectedDevices(),
                const SizedBox(height: 16),
                ..._scenes.map(_buildSceneCard),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSceneComposer(),
        icon: const Icon(Icons.add),
        label: const Text('Compose scene'),
      ),
    );
  }

  Widget _buildConnectedDevices() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connected devices',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_devices.isEmpty)
              const Text('No devices linked yet. Connect via caregiver settings.')
            else
              ..._devices.map((device) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      device.platform == 'alexa'
                          ? Icons.speaker
                          : device.platform == 'homekit'
                              ? Icons.home_filled
                              : Icons.sensors,
                    ),
                    title: Text(device.displayName),
                    subtitle: Text(device.capabilities.join(', ')),
                    trailing: Icon(
                      device.linked ? Icons.check_circle : Icons.info_outline,
                      color: device.linked ? Colors.greenAccent : Colors.orange,
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildSceneCard(SmartScene scene) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scene.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(scene.description),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _triggerScene(scene),
                  icon: const Icon(Icons.play_circle_filled),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...scene.actions.map((action) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        action.deviceType == 'lights'
                            ? Icons.light_mode
                            : action.deviceType == 'sound'
                                ? Icons.music_note
                                : Icons.air,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(action.value)),
                      if (action.delaySeconds > 0)
                        Text('+${action.delaySeconds}s delay'),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _showSceneComposer() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final actions = <SceneAction>[];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New scene'),
        content: StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          actions.add(
                            SceneAction(deviceType: 'lights', value: '50%'),
                          );
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add action'),
                    ),
                  ),
                  ...actions.asMap().entries.map(
                        (entry) => ListTile(
                          title: Text('Action ${entry.key + 1}'),
                          subtitle: Text('${entry.value.deviceType} • ${entry.value.value}'),
                          trailing: IconButton(
                            onPressed: () {
                              setState(() => actions.removeAt(entry.key));
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              final scene = SmartScene(
                id: 'scene_${DateTime.now().millisecondsSinceEpoch}',
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
                actions: actions.isEmpty
                    ? SmartScene.defaults.first.actions
                    : actions,
              );
              await _smartHomeService.upsertScene(scene);
              if (!mounted) return;
              Navigator.of(context).pop();
              _loadData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

