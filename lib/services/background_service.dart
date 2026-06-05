import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart'
    hide ServiceStatus;
import 'package:runhutch/functions/bl_functions.dart';
import 'package:runhutch/services/request.dart';

const _notificationChannelId = 'runhutch_booster';
const _notificationId = 1001;
const _notificationIcon = 'ic_notification';

Future<void> _ensureNotificationPlugin(
  FlutterLocalNotificationsPlugin plugin,
) async {
  if (!Platform.isAndroid) return;

  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings(_notificationIcon),
    ),
  );
}

Future<void> _showServiceNotification(
  FlutterLocalNotificationsPlugin plugin, {
  required String title,
  required String content,
}) async {
  await plugin.show(
    id: _notificationId,
    title: title,
    body: content,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _notificationChannelId,
        'Network Booster',
        channelDescription: 'Shows Network Booster service status',
        icon: _notificationIcon,
        ongoing: true,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        onlyAlertOnce: true,
      ),
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final notifications = FlutterLocalNotificationsPlugin();
  await _ensureNotificationPlugin(notifications);

  Timer? timer;
  var requestCount = 0;
  var lastStatus = 'Starting...';

  Future<void> publishStatus() async {
    await BlFunctions.saveServiceStatus(
      isActive: true,
      requestCount: requestCount,
      lastStatus: lastStatus,
    );

    const title = 'RunHutch · Network Booster';
    final content = '$requestCount requests · $lastStatus';

    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        await _showServiceNotification(
          notifications,
          title: title,
          content: content,
        );
        await service.setForegroundNotificationInfo(
          title: title,
          content: content,
        );
      }
    }

    service.invoke('update', {
      'requestCount': requestCount,
      'lastStatus': lastStatus,
    });
  }

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) async {
      await service.setAsForegroundService();
      await _showServiceNotification(
        notifications,
        title: 'RunHutch · Network Booster',
        content: 'Starting service...',
      );
    });

    service.on('setAsBackground').listen((_) async {
      await service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((_) async {
    timer?.cancel();
    await notifications.cancel(id: _notificationId);
    await BlFunctions.saveServiceStatus(
      isActive: false,
      requestCount: requestCount,
      lastStatus: 'Stopped',
    );
    await service.stopSelf();
  });

  final settings = await BlFunctions.loadSettings();
  final url = BlFunctions.normalizeUrl(settings.url);
  final intervalSeconds = settings.intervalSeconds;

  Future<void> runRequest() async {
    final result = await RequestService.send(url);
    requestCount++;
    lastStatus = result.statusLabel;
    await publishStatus();
  }

  await runRequest();

  timer = Timer.periodic(
    Duration(seconds: intervalSeconds),
    (_) => runRequest(),
  );
}

class BackgroundService {
  BackgroundService._();

  static final BackgroundService instance = BackgroundService._();

  final _notifications = FlutterLocalNotificationsPlugin();
  final _statusController = StreamController<ServiceStatus>.broadcast();

  int _requestCount = 0;
  String? _lastStatus;
  bool _isRunning = false;
  bool _initialized = false;
  StreamSubscription<Map<String, dynamic>?>? _updateSubscription;

  bool get isRunning => _isRunning;
  int get requestCount => _requestCount;
  String? get lastStatus => _lastStatus;
  Stream<ServiceStatus> get statusStream => _statusController.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    await _ensureNotificationPlugin(_notifications);

    const channel = AndroidNotificationChannel(
      _notificationChannelId,
      'Network Booster',
      description: 'Shows Network Booster service status',
      importance: Importance.defaultImportance,
      playSound: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _notificationChannelId,
        initialNotificationTitle: 'RunHutch · Network Booster',
        initialNotificationContent: 'Starting...',
        foregroundServiceNotificationId: _notificationId,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: _onIosBackground,
      ),
    );

    _updateSubscription =
        FlutterBackgroundService().on('update').listen(_handleUpdate);

    await _syncFromStorage();
    _isRunning = await service.isRunning();
    _initialized = true;
    _emitStatus();
  }

  Future<void> start() async {
    await initialize();
    await _requestNotificationPermission();
    await _requestBatteryOptimizationExemption();

    await BlFunctions.resetServiceStatus();
    _requestCount = 0;
    _lastStatus = 'Starting...';

    final service = FlutterBackgroundService();
    final alreadyRunning = await service.isRunning();
    if (!alreadyRunning) {
      await service.startService();
    }

    if (Platform.isAndroid) {
      service.invoke('setAsForeground');
    }

    _isRunning = true;
    _emitStatus();
  }

  Future<void> stop() async {
    if (!_isRunning && !await FlutterBackgroundService().isRunning()) {
      return;
    }

    FlutterBackgroundService().invoke('stopService');
    await _notifications.cancel(id: _notificationId);

    _isRunning = false;
    _lastStatus = 'Stopped';

    await BlFunctions.saveServiceStatus(
      isActive: false,
      requestCount: _requestCount,
      lastStatus: _lastStatus,
    );
    _emitStatus();
  }

  Future<void> refreshStatus() async {
    await _syncFromStorage();
    _isRunning = await FlutterBackgroundService().isRunning();
    _emitStatus();
  }

  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid) return;

    final plugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await plugin?.requestNotificationsPermission();
    await Permission.notification.request();
  }

  Future<void> _requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return;

    final status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  Future<void> _syncFromStorage() async {
    final status = await BlFunctions.loadServiceStatus();
    _requestCount = status.requestCount;
    _lastStatus = status.lastStatus;
  }

  void _handleUpdate(Map<String, dynamic>? data) {
    if (data == null) return;

    _requestCount = data['requestCount'] as int? ?? _requestCount;
    _lastStatus = data['lastStatus'] as String? ?? _lastStatus;
    _isRunning = true;
    _emitStatus();
  }

  void _emitStatus() {
    if (_statusController.isClosed) return;
    _statusController.add(
      ServiceStatus(
        isActive: _isRunning,
        requestCount: _requestCount,
        lastStatus: _lastStatus,
      ),
    );
  }

  void dispose() {
    _updateSubscription?.cancel();
    _statusController.close();
  }
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}
