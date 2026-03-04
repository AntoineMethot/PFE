class ImuSample {
  final double t; // seconds since start of recording (or device time if you later add it)
  final int seq;
  final int ax, ay, az; // raw as received (mg if your firmware sends mg)
  final int gx, gy, gz; // raw as received (centi-deg/s if your firmware sends that)

  ImuSample({
    required this.t,
    required this.seq,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });

  String toCsv() => '$t,$seq,$ax,$ay,$az,$gx,$gy,$gz';
}