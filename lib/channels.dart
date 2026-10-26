import 'package:flutter/material.dart';

/// Canais da luminária (ordem da TC421: CH1..CH5).
/// Aquário marinho: não há canal vermelho.
const List<Color> channelColors = [
  Color(0xFF4F6BFF), // CH1 Royal Blue
  Color(0xFF2FA4FF), // CH2 Blue
  Color(0xFF22E3EE), // CH3 Ciano
  Color(0xFFEAF2FF), // CH4 Branco
  Color(0xFFB06BFF), // CH5 Violeta
];

const List<String> channelNames = [
  'Royal Blue',
  'Blue',
  'Ciano',
  'Branco',
  'Violeta',
];

const List<String> channelDetails = [
  '450–465 nm',
  '470 nm',
  '490 nm',
  '6500 K',
  '420 nm',
];

const List<IconData> channelIcons = [
  Icons.nightlight_round,
  Icons.water_drop_outlined,
  Icons.waves,
  Icons.wb_sunny_outlined,
  Icons.auto_awesome,
];

/// Centro (nm) e largura de cada canal, para os desenhos de espectro.
const List<double> channelCenters = [457, 470, 492, 560, 420];
const List<double> channelWidths = [12, 12, 15, 65, 10];
