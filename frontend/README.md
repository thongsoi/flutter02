# frontend

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
1


setup environment and test android on linux

Option #1 (machine ip address)
How to find your machine's ip address
$ ifconfig | grep "inet " | grep -v 127.0.0.1 
you will see inet 192.168.1.223

Option #2 (main.dart code)
static const String baseUrl = 'http://10.0.2.2:8080/api';