import 'dart:convert';

class HotelSearchResult {
  final Meta meta;
  final List<Hotel> results;

  const HotelSearchResult({
    required this.meta,
    required this.results,
  });

  factory HotelSearchResult.fromJson(Map<String, dynamic> json) {
    return HotelSearchResult(
      meta: Meta.fromJson((json['meta'] as Map).cast<String, dynamic>()),
      results: (json['results'] as List? ?? const [])
          .map((e) => Hotel.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'meta': meta.toJson(),
        'results': results.map((e) => e.toJson()).toList(growable: false),
      };

  static HotelSearchResult fromJsonString(String body) {
    final decoded = jsonDecode(body);
    return HotelSearchResult.fromJson((decoded as Map).cast<String, dynamic>());
  }
}

class Meta {
  final String? location;
  final String? checkIn;
  final String? checkOut;
  final int? nights;
  final int? adults;
  final int? count;

  const Meta({
    required this.location,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.adults,
    required this.count,
  });

  factory Meta.fromJson(Map<String, dynamic> json) {
    return Meta(
      location: json['location'] as String?,
      checkIn: json['check_in'] as String?,
      checkOut: json['check_out'] as String?,
      nights: (json['nights'] as num?)?.toInt(),
      adults: (json['adults'] as num?)?.toInt(),
      count: (json['count'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'location': location,
        'check_in': checkIn,
        'check_out': checkOut,
        'nights': nights,
        'adults': adults,
        'count': count,
      };
}

class Hotel {
  final String key;
  final String name;
  final String? accommodationType;
  final Review? review;
  final List<dynamic> mentions;
  final List<dynamic> merchandisingLabels;
  final PriceRanges? priceRanges;
  final String? url;
  final List<Rate> rates;

  const Hotel({
    required this.key,
    required this.name,
    required this.accommodationType,
    required this.review,
    required this.mentions,
    required this.merchandisingLabels,
    required this.priceRanges,
    required this.url,
    required this.rates,
  });

  factory Hotel.fromJson(Map<String, dynamic> json) {
    return Hotel(
      key: (json['key'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      accommodationType: json['accommodation_type'] as String?,
      review: json['review'] is Map
          ? Review.fromJson((json['review'] as Map).cast<String, dynamic>())
          : null,
      mentions: (json['mentions'] as List?) ?? const [],
      merchandisingLabels: (json['merchandising_labels'] as List?) ?? const [],
      priceRanges: json['price_ranges'] is Map
          ? PriceRanges.fromJson((json['price_ranges'] as Map).cast<String, dynamic>())
          : null,
      url: json['url'] as String?,
      rates: (json['rates'] as List? ?? const [])
          .map((e) => Rate.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'accommodation_type': accommodationType,
        'review': review?.toJson(),
        'mentions': mentions,
        'merchandising_labels': merchandisingLabels,
        'price_ranges': priceRanges?.toJson(),
        'url': url,
        'rates': rates.map((e) => e.toJson()).toList(growable: false),
      };
}

class Review {
  final double? rating;
  final int? count;

  const Review({
    required this.rating,
    required this.count,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      rating: (json['rating'] as num?)?.toDouble(),
      count: (json['count'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'rating': rating,
        'count': count,
      };
}

class PriceRanges {
  final double? minimum;
  final double? maximum;

  const PriceRanges({
    required this.minimum,
    required this.maximum,
  });

  factory PriceRanges.fromJson(Map<String, dynamic> json) {
    return PriceRanges(
      minimum: (json['minimum'] as num?)?.toDouble(),
      maximum: (json['maximum'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'minimum': minimum,
        'maximum': maximum,
      };
}

class Rate {
  final String? code;
  final String? name;
  final double? rate;
  final double? tax;
  final double? perNight;
  final double? totalForStay;

  const Rate({
    required this.code,
    required this.name,
    required this.rate,
    required this.tax,
    required this.perNight,
    required this.totalForStay,
  });

  factory Rate.fromJson(Map<String, dynamic> json) {
    return Rate(
      code: json['code'] as String?,
      name: json['name'] as String?,
      rate: (json['rate'] as num?)?.toDouble(),
      tax: (json['tax'] as num?)?.toDouble(),
      perNight: (json['per_night'] as num?)?.toDouble(),
      totalForStay: (json['total_for_stay'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'rate': rate,
        'tax': tax,
        'per_night': perNight,
        'total_for_stay': totalForStay,
      };
}
