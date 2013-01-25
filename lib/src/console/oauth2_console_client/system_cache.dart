// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library system_cache;

import 'dart:io';
import 'dart:async';


import 'io.dart';
import 'io.dart' as io show createTempDir;
import 'log.dart' as log;

import 'utils.dart';


/// The system-wide cache of installed packages.
///
/// This cache contains all packages that are downloaded from the internet.
/// Packages that are available locally (e.g. from the SDK) don't use this
/// cache.
class SystemCache {
  /// The root directory where this package cache is located.
  final String rootDir;

  String get tempDir => join(rootDir, '_temp');


  /// Creates a new package cache which is backed by the given directory on the
  /// user's file system.
  SystemCache(this.rootDir);

  /// Creates a system cache and registers the standard set of sources.
  factory SystemCache.withSources(String rootDir) {
    var cache = new SystemCache(rootDir);

    return cache;
  }




  /// Create a new temporary directory within the system cache. The system
  /// cache maintains its own temporary directory that it uses to stage
  /// packages into while installing. It uses this instead of the OS's system
  /// temp directory to ensure that it's on the same volume as the pub system
  /// cache so that it can move the directory from it.
  Future<Directory> createTempDir() {
    return ensureDir(tempDir).then((temp) {
      return io.createTempDir(join(temp, 'dir'));
    });
  }

  /// Delete's the system cache's internal temp directory.
  Future deleteTempDir() {
    log.fine('Clean up system cache temp directory $tempDir.');
    return dirExists(tempDir).then((exists) {
      if (!exists) return new Future.immediate(null);
      return deleteDir(tempDir);
    });
  }
}
