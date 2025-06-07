import 'package:flutter/material.dart';


/// Use like this:
///      MaterialApp.router(
///        scaffoldMessengerKey: NotificationService.messengerKey,
class NotificationService {
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void showError(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    );
    messengerKey.currentState?.showSnackBar(snackBar);
  }

  static void showOk(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    );
    messengerKey.currentState?.showSnackBar(snackBar);
  }

  static void showWarning(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Colors.yellow,
    );
    messengerKey.currentState?.showSnackBar(snackBar);
  }

  static void showDev(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Colors.purple.shade500,
    );
    messengerKey.currentState?.showSnackBar(snackBar);
  }
}

void showErrorNotification(String message) {
  return NotificationService.showError(message);
}

void showDevNotification(String message) {
  return NotificationService.showDev(message);
}

void showOkNotification(String message) => NotificationService.showOk(message);

void showWarningNotification(String message) => NotificationService.showWarning(message);
