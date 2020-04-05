part of gpm;

class GpmConfig {
  final List<GpmPackage> packages = <GpmPackage>[];
  final Map<String, GpmStep> scripts = <String, GpmStep>{};

  GpmConfig();

  factory GpmConfig.fromYaml(Object yaml) {
    if (yaml is Map) {
      final result = GpmConfig();
      for (var entry in yaml.entries) {
        final key = entry.key;
        switch (key) {
          case 'packages':
            final yaml = entry.value as List;
            var index = 0;
            for (var partYaml in yaml) {
              result.packages.add(
                GpmPackage.fromYaml(partYaml, path: ['packages', '$index']),
              );
              index++;
            }
            break;

          case 'scripts':
            final yaml = entry.value as Map;
            for (var entry in yaml.entries) {
              final key = entry.key as String;
              final value =
                  GpmStep.fromYaml(entry.value, path: ['scripts', key]);
              result.scripts[key] = value;
            }
            break;

          default:
            throw StateError('Unsupported key "$key" in /');
        }
      }
      return result;
    } else {
      throw ArgumentError.value(yaml);
    }
  }

  Map<String, Object> toYaml() {
    final yaml = <String, Object>{};
    yaml['packages'] = packages.map((e) => e.toYaml()).toList();
    yaml['scripts'] = scripts
        .map((key, value) => MapEntry<String, Object>(key, value.toYaml()));
    return yaml;
  }

  static Iterable<GpmPackage> findParts({Directory root}) sync* {
    root ??= Directory.current;
    if (root is Directory) {
      final gpmFile = File.fromUri(root.uri.resolve('gpm.yaml'));
      if (gpmFile.existsSync()) {
        final yaml = loadYaml(gpmFile.readAsStringSync());
        final packages = GpmConfig.fromYaml(yaml).packages;
        for (var part in packages) {
          part.path = root.uri.resolve(part.path).path;
        }
        yield* (packages);
        return;
      }
      final pubspecFile = File.fromUri(root.uri.resolve('pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        final subdirectories = root.listSync();
        subdirectories.sort((a, b) => a.path.compareTo(b.path));
        yield (GpmPackage()..path = root.path);
        for (var subdirectory in subdirectories) {
          if (subdirectory is Directory) {
            final name = _fileName(subdirectory.path);
            if (name != 'lib' &&
                name != 'web' &&
                name != 'build' &&
                !name.startsWith('.')) {
              yield* (findParts(root: subdirectory));
            }
          }
        }
        return;
      }

      final subdirectories = root.listSync();
      subdirectories.sort((a, b) => a.path.compareTo(b.path));
      for (var subdirectory in subdirectories) {
        if (subdirectory is Directory) {
          final name = _fileName(subdirectory.path);
          if (!name.startsWith('.')) {
            yield* (findParts(root: subdirectory));
          }
        }
      }
    }
  }

  static GpmConfig get() {
    final gpmFile = File('gpm.yaml');
    if (gpmFile.existsSync()) {
      final yaml = loadYaml(gpmFile.readAsStringSync());
      return GpmConfig.fromYaml(yaml);
    }
    final result = GpmConfig();
    result.packages.addAll(findParts());
    return result;
  }
}
