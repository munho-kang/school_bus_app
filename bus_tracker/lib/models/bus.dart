// 버스 실시간 위치·상태 데이터를 표현하는 모델.
class Bus {
  final String busId;
  final double latitude;
  final double longitude;
  final String? station;
  final String? nextStation;
  final String? status;
  final num? progress;
  final bool? isRecent;

  Bus({
    required this.busId,
    required this.latitude,
    required this.longitude,
    this.station,
    this.nextStation,
    this.status,
    this.progress,
    this.isRecent,
   });

  factory Bus.fromJson(Map<String, dynamic> json) => Bus(
    busId: (json['busId'] ?? '').toString(),
    latitude: (json['latitude'] ?? 0).toDouble(),
    longitude: (json['longitude'] ?? 0).toDouble(),
    station: json['station']?.toString(),
    nextStation: json['nextStation']?.toString(),
    status: json['status']?.toString(),
    progress: json['progress'] != null ? json['progress'] as num : null,
     isRecent: json['isRecent'] as bool?,
   );

  Map<String, dynamic> toJson() => {
    'busId': busId,
    'latitude': latitude,
    'longitude': longitude,
    'station': station,
    'nextStation': nextStation,
    'status': status,
    'progress': progress,
    'isRecent': isRecent,
   };
}
