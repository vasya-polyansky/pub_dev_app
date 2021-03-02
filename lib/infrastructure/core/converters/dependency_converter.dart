import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pub_semver/pub_semver.dart';

import 'package:pub_dev_app/infrastructure/pub_api/dtos/dependency_dto/dependency_dto.dart';

abstract class SourceKeys {
  static const sdk = 'sdk';
  static const git = 'git';
  static const path = 'path';
  static const hosted = 'hosted';

  static const values = [
    sdk,
    git,
    path,
    hosted,
  ];
}

DependencyDto dependencyFromJson(Object json) {
  // dependencies:
  //   transmogrify: ^1.4.0
  //
  // dependencies:
  //   transmogrify: any
  //
  // dependencies:
  //   transmogrify:          (with no version)
  if (json is String || json == null) {
    return DependencyDto.hosted(
      version: VersionConstraint.parse(json),
    );
  }

  if (json is Map) {
    final matchedKeys = json.keys.cast<String>().where((key) => key != 'version').toList();
    final jsonHasOnlyVersion = matchedKeys.isEmpty && json.containsKey('version');

    // dependencies:
    //   transmogrify: {}
    //
    // dependencies:
    //   transmogrify:
    //     version: ^1.4.0
    if (json.isEmpty || jsonHasOnlyVersion) {
      return HostedDependencyDto.fromJson(json);
    }

    // Unknown dependency option.
    final firstUnrecognizedKey = matchedKeys.firstWhere(
      (key) => !SourceKeys.values.contains(key),
      orElse: () => null,
    );
    if (firstUnrecognizedKey != null) {
      throw UnrecognizedKeysException(
        [firstUnrecognizedKey],
        json,
        SourceKeys.values,
      );
    }

    // A few sources.
    if (matchedKeys.length > 1) {
      throw CheckedFromJsonException(
        json,
        matchedKeys.first,
        'DependencyDto',
        'A dependency may only have one source.',
      );
    }

    final key = matchedKeys.single;

    switch (key) {
      case SourceKeys.git:
        final value = json[key];
        // dependencies:
        //  kittens:
        //    git: https://github.com/munificent/kittens.git
        if (value is String) {
          return GitDependencyDto(url: value);
        }
        // dependencies:
        //   kittens:
        //     git:
        //       url: git@github.com:munificent/kittens.git
        //       ref: some-branch
        if (value is Map) {
          return GitDependencyDto.fromJson(value);
        }
        throw AssertionError();

      case SourceKeys.path:
        // dependencies:
        //   transmogrify:
        //     path: /Users/me/transmogrify
        return PathDependencyDto.fromJson(json);

      case SourceKeys.sdk:
        // dependencies:
        //   flutter_driver:
        //     sdk: flutter
        //     version: ^0.0.1
        return SdkDependencyDto.fromJson(json);

      case SourceKeys.hosted:
        // dependencies:
        //   transmogrify:
        //     hosted:
        //       name: transmogrify
        //       url: http://your-package-server.com
        //     version: ^1.4.0
        return HostedDependencyDto.fromJson(json);
    }
  }

  throw AssertionError('Unhandled case in the dependency parsing.');
}

class DependencyDtoConverter implements JsonConverter<DependencyDto, Object> {
  @override
  DependencyDto fromJson(Object json) => dependencyFromJson(json);

  @override
  Object toJson(DependencyDto dependency) => dependency?.toJson();
}
