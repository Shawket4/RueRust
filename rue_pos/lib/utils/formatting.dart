String formatEGP(int piastres) {
  final egp = piastres / 100;
  if (egp == egp.truncateToDouble()) {
    return 'EGP ${egp.toInt()}';
  }
  return 'EGP ${egp.toStringAsFixed(2)}';
}

String formatEGPDouble(double piastres) => formatEGP(piastres.round());
