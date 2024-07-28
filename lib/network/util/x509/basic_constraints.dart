/// @author wanghongen
/// 2024/7/28
class BasicConstraints {
  final bool isCA;
  final int? pathLenConstraint;
  final bool critical;

  BasicConstraints({required this.isCA, this.pathLenConstraint, this.critical = true});
}
