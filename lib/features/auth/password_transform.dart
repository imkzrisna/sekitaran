import 'dart:convert';

import 'package:crypto/crypto.dart';

String transformPasswordForSupabase(String password) =>
    sha256.convert(utf8.encode(password)).toString();
