import 'package:flutter_test/flutter_test.dart';
import 'package:tc421_app/curve.dart';

void main() {
  test('curva do dia: subida, topo e descida', () {
    final c = DayCurve.daylight();
    expect(c.valueAt(0), 0);
    expect(c.valueAt(420), 0);
    expect(c.valueAt(480), 50); // meio da subida (07:00 a 09:00)
    expect(c.valueAt(540), 100);
    expect(c.valueAt(600), 100);
    expect(c.valueAt(1200), 50); // meio da descida (19:00 a 21:00)
    expect(c.valueAt(1260), 0);
    expect(c.valueAt(1410), 0);
  });

  test('curva plana', () {
    final c = DayCurve.flat(70);
    expect(c.valueAt(0), 70);
    expect(c.valueAt(700), 70);
    expect(c.valueAt(1440), 70);
  });

  test('criar ponto arredonda para 30 minutos e mantém a ordem', () {
    final c = DayCurve.flat(0);
    final i = c.addPoint(725, 60);
    expect(i, 1);
    expect(c.points[1].minute, 720);
    expect(c.points[1].value, 60);
    expect(c.valueAt(360), 30); // metade da subida de 00:00 até 12:00
  });

  test('não cria dois pontos no mesmo horário nem nas pontas', () {
    final c = DayCurve.flat(0);
    expect(c.addPoint(720, 50), 1);
    expect(c.addPoint(730, 80), -1); // também arredonda para 720
    expect(c.addPoint(0, 80), -1);
    expect(c.addPoint(1440, 80), -1);
    expect(c.points.length, 3);
  });

  test('mover ponto respeita vizinhos e limites', () {
    final c = DayCurve.flat(0)..addPoint(720, 50);
    c.move(1, 5000, 150);
    expect(c.points[1].minute, 1410); // 30 min antes de 24:00
    expect(c.points[1].value, 100);
    c.move(1, -5000, -20);
    expect(c.points[1].minute, 30); // 30 min depois de 00:00
    expect(c.points[1].value, 0);
  });

  test('pontas só mudam de intensidade', () {
    final c = DayCurve.flat(0);
    c.move(0, 600, 40);
    expect(c.points[0].minute, 0);
    expect(c.points[0].value, 40);
    c.move(1, 100, 90);
    expect(c.points[1].minute, 1440);
    expect(c.points[1].value, 90);
  });

  test('apagar ponto: as pontas ficam', () {
    final c = DayCurve.flat(0)..addPoint(720, 50);
    c.removeAt(0);
    c.removeAt(2);
    expect(c.points.length, 3);
    c.removeAt(1);
    expect(c.points.length, 2);
  });

  test('copiar não compartilha pontos', () {
    final a = DayCurve.daylight();
    final b = a.copy();
    b.move(2, 600, 10);
    expect(a.points[2].value, 100);
  });

  test('rótulo de horário', () {
    expect(timeLabel(0), '00:00');
    expect(timeLabel(510), '08:30');
    expect(timeLabel(1440), '24:00');
  });
}
