import 'dart:convert';

class TransportSearchResult {
  final TransportMeta meta;
  final List<Journey> results;

  const TransportSearchResult({
    required this.meta,
    required this.results,
  });

  factory TransportSearchResult.fromJson(Map<String, dynamic> json) {
    return TransportSearchResult(
      meta: TransportMeta.fromJson((json['meta'] as Map).cast<String, dynamic>()),
      results: (json['results'] as List? ?? const [])
          .map((e) => Journey.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'meta': meta.toJson(),
        'results': results.map((e) => e.toJson()).toList(growable: false),
      };

  static TransportSearchResult fromJsonString(String body) {
    final decoded = jsonDecode(body);
    return TransportSearchResult.fromJson((decoded as Map).cast<String, dynamic>());
  }
}

class TransportMeta {
  final String? from;
  final String? to;
  final String? date;
  final int? count;

  const TransportMeta({
    required this.from,
    required this.to,
    required this.date,
    required this.count,
  });

  factory TransportMeta.fromJson(Map<String, dynamic> json) {
    return TransportMeta(
      from: json['from'] as String?,
      to: json['to'] as String?,
      date: json['date'] as String?,
      count: (json['count'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'date': date,
        'count': count,
      };
}

/// A single public-transport connection from origin to destination.
class Journey {
  final String summary;
  final String? icon;
  final int? durationMinutes;
  final String? durationText;
  final int transfers;
  final String? departure;
  final String? arrival;
  final String? fromName;
  final String? toName;
  final List<JourneyLeg> legs;

  const Journey({
    required this.summary,
    required this.icon,
    required this.durationMinutes,
    required this.durationText,
    required this.transfers,
    required this.departure,
    required this.arrival,
    required this.fromName,
    required this.toName,
    required this.legs,
  });

  factory Journey.fromJson(Map<String, dynamic> json) {
    return Journey(
      summary: (json['summary'] as String?) ?? '',
      icon: json['icon'] as String?,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      durationText: json['duration_text'] as String?,
      transfers: (json['transfers'] as num?)?.toInt() ?? 0,
      departure: json['departure'] as String?,
      arrival: json['arrival'] as String?,
      fromName: json['from_name'] as String?,
      toName: json['to_name'] as String?,
      legs: (json['legs'] as List? ?? const [])
          .map((e) => JourneyLeg.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'icon': icon,
        'duration_minutes': durationMinutes,
        'duration_text': durationText,
        'transfers': transfers,
        'departure': departure,
        'arrival': arrival,
        'from_name': fromName,
        'to_name': toName,
        'legs': legs.map((e) => e.toJson()).toList(growable: false),
      };
}

/// A single segment of a journey (one vehicle ride or a walk).
class JourneyLeg {
  final String mode;
  final String modeLabel;
  final String? icon;
  final String? line;
  final String? headsign;
  final String? agency;
  final String? fromName;
  final String? toName;
  final String? departure;
  final String? arrival;
  final String? durationText;
  final int stops;
  final double? distanceKm;
  final String? departureTrack;
  final String? arrivalTrack;
  final bool realTime;

  const JourneyLeg({
    required this.mode,
    required this.modeLabel,
    required this.icon,
    required this.line,
    required this.headsign,
    required this.agency,
    required this.fromName,
    required this.toName,
    required this.departure,
    required this.arrival,
    required this.durationText,
    required this.stops,
    required this.distanceKm,
    required this.departureTrack,
    required this.arrivalTrack,
    required this.realTime,
  });

  bool get isWalk => mode == 'WALK';

  factory JourneyLeg.fromJson(Map<String, dynamic> json) {
    return JourneyLeg(
      mode: (json['mode'] as String?) ?? '',
      modeLabel: (json['mode_label'] as String?) ?? '',
      icon: json['icon'] as String?,
      line: json['line'] as String?,
      headsign: json['headsign'] as String?,
      agency: json['agency'] as String?,
      fromName: json['from_name'] as String?,
      toName: json['to_name'] as String?,
      departure: json['departure'] as String?,
      arrival: json['arrival'] as String?,
      durationText: json['duration_text'] as String?,
      stops: (json['stops'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      departureTrack: json['departure_track'] as String?,
      arrivalTrack: json['arrival_track'] as String?,
      realTime: (json['real_time'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'mode_label': modeLabel,
        'icon': icon,
        'line': line,
        'headsign': headsign,
        'agency': agency,
        'from_name': fromName,
        'to_name': toName,
        'departure': departure,
        'arrival': arrival,
        'duration_text': durationText,
        'stops': stops,
        'distance_km': distanceKm,
        'departure_track': departureTrack,
        'arrival_track': arrivalTrack,
        'real_time': realTime,
      };
}
