import 'package:flutter/material.dart';

/// Hedef kas grubu.
enum Muscle {
  chest('Göğüs', Icons.fitness_center),
  back('Sırt', Icons.accessibility_new),
  shoulders('Omuz', Icons.sports_gymnastics),
  arms('Kol', Icons.sports_martial_arts),
  legs('Bacak', Icons.directions_walk),
  core('Karın', Icons.self_improvement),
  fullBody('Tüm Vücut', Icons.bolt),
  cardio('Kardiyo', Icons.favorite);

  final String label;
  final IconData icon;
  const Muscle(this.label, this.icon);
}

enum Level {
  beginner('Başlangıç'),
  intermediate('Orta'),
  advanced('İleri');

  final String label;
  const Level(this.label);
}

enum Equipment {
  none('Ekipmansız'),
  dumbbell('Dambıl'),
  barbell('Halter'),
  machine('Makine'),
  cable('Kablo'),
  bodyweightBar('Barfiks barı');

  final String label;
  const Equipment(this.label);
}

class Exercise {
  final String id;
  final String name;
  final Muscle muscle;
  final Equipment equipment;
  final Level level;

  /// Varsayılan set / tekrar. Süreli egzersizlerde [durationSec] kullanılır.
  final int sets;
  final int reps;
  final int? durationSec;
  final int restSec;

  final List<String> steps;
  final List<String> tips;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscle,
    required this.equipment,
    required this.level,
    required this.steps,
    required this.tips,
    this.sets = 3,
    this.reps = 12,
    this.durationSec,
    this.restSec = 60,
  });

  bool get isTimed => durationSec != null;

  bool get isGym =>
      equipment != Equipment.none && equipment != Equipment.bodyweightBar;

  String get prescription =>
      isTimed ? '$sets × ${durationSec}sn' : '$sets × $reps';
}

/// Uygulamayla gelen çevrimdışı egzersiz kütüphanesi.
const List<Exercise> exerciseLibrary = [
  // ── GÖĞÜS ──────────────────────────────────────────────────────────────
  Exercise(
    id: 'pushup', name: 'Şınav', muscle: Muscle.chest,
    equipment: Equipment.none, level: Level.beginner, sets: 3, reps: 12, restSec: 45,
    steps: [
      'Ellerini omuz genişliğinden biraz açık olacak şekilde yere koy.',
      'Vücudun başından topuğuna düz bir çizgi olsun.',
      'Göğsün yere yaklaşana kadar dirseklerini bükerek in.',
      'Yere iterek başlangıç pozisyonuna dön.',
    ],
    tips: ['Belini çökertme, karnını sık.', 'Zorsa dizlerinin üzerinde yap.'],
  ),
  Exercise(
    id: 'bench_press', name: 'Bench Press (Halter)', muscle: Muscle.chest,
    equipment: Equipment.barbell, level: Level.intermediate, sets: 4, reps: 8, restSec: 90,
    steps: [
      'Sehpaya sırtüstü uzan, ayakların yerde sağlam dursun.',
      'Barı omuz genişliğinden biraz geniş tut ve rafından çıkar.',
      'Barı kontrollü şekilde göğsünün alt kısmına indir.',
      'Göğsünden yukarı doğru it, kollar tam açılsın.',
    ],
    tips: ['Yanında yardımcı (spotter) bulundur.', 'Kalçanı sehpadan kaldırma.'],
  ),
  Exercise(
    id: 'db_press', name: 'Dambıl Press', muscle: Muscle.chest,
    equipment: Equipment.dumbbell, level: Level.beginner, sets: 3, reps: 10, restSec: 75,
    steps: [
      'Sehpaya uzan, dambılları göğüs hizasında tut.',
      'Dirsekler gövdeye yaklaşık 45° açıda olsun.',
      'Dambılları yukarı doğru it, üstte hafifçe birleştir.',
      'Yavaşça başlangıca in.',
    ],
    tips: ['İnişi 2-3 saniyede yap.', 'Omuzlarını geriye ve aşağıya çek.'],
  ),
  Exercise(
    id: 'incline_db_press', name: 'Eğimli Dambıl Press', muscle: Muscle.chest,
    equipment: Equipment.dumbbell, level: Level.intermediate, sets: 3, reps: 10, restSec: 75,
    steps: [
      'Sehpayı 30-45° eğime ayarla ve uzan.',
      'Dambılları üst göğüs hizasında tut.',
      'Yukarı doğru it, kollar uzayana kadar.',
      'Kontrollü şekilde indir.',
    ],
    tips: ['Eğimi çok yüksek yapma; omuzlar devreye girer.'],
  ),
  Exercise(
    id: 'cable_fly', name: 'Kablo Fly', muscle: Muscle.chest,
    equipment: Equipment.cable, level: Level.intermediate, sets: 3, reps: 12, restSec: 60,
    steps: [
      'Makaraları omuz hizasına ayarla, ortada dur.',
      'Dirsekleri hafif bükük tutarak kolları öne doğru birleştir.',
      'Göğsünde sıkışmayı hisset, 1 saniye bekle.',
      'Yavaşça açılarak başlangıca dön.',
    ],
    tips: ['Hareket kolun değil göğsün işi; ağırlığı abartma.'],
  ),
  // ── SIRT ───────────────────────────────────────────────────────────────
  Exercise(
    id: 'pullup', name: 'Barfiks', muscle: Muscle.back,
    equipment: Equipment.bodyweightBar, level: Level.advanced, sets: 3, reps: 6, restSec: 90,
    steps: [
      'Bara omuz genişliğinden geniş, avuç dışa bakacak şekilde tutun.',
      'Kürek kemiklerini aşağı çekerek kendini kaldır.',
      'Çene bar hizasını geçene kadar yüksel.',
      'Kontrollü şekilde sarkma pozisyonuna in.',
    ],
    tips: ['Sallanma; momentum kullanma.', 'Zorsa lastik bant veya asistan makine kullan.'],
  ),
  Exercise(
    id: 'lat_pulldown', name: 'Lat Pulldown', muscle: Muscle.back,
    equipment: Equipment.machine, level: Level.beginner, sets: 3, reps: 12, restSec: 60,
    steps: [
      'Dizlerini pedlere sabitle, barı geniş tut.',
      'Göğsünü hafif öne çıkar, barı köprücük kemiğine doğru çek.',
      'Dirsekleri aşağı ve yana sür.',
      'Yavaşça yukarı bırak.',
    ],
    tips: ['Barı ensene çekme.', 'Omuzları kulaklardan uzak tut.'],
  ),
  Exercise(
    id: 'bent_row', name: 'Bent-Over Row', muscle: Muscle.back,
    equipment: Equipment.barbell, level: Level.intermediate, sets: 4, reps: 8, restSec: 90,
    steps: [
      'Ayaklar omuz genişliğinde, dizler hafif bükük, gövde öne eğik.',
      'Barı yerden diz altına kadar kaldır, sırt düz.',
      'Barı göbeğine doğru çek, kürek kemiklerini sık.',
      'Kontrollü şekilde indir.',
    ],
    tips: ['Beli yuvarlama; bakışın yere doğru olsun.'],
  ),
  Exercise(
    id: 'db_row', name: 'Tek Kol Dambıl Row', muscle: Muscle.back,
    equipment: Equipment.dumbbell, level: Level.beginner, sets: 3, reps: 12, restSec: 60,
    steps: [
      'Bir diz ve bir elini sehpaya koy, sırt yere paralel.',
      'Dambılı serbest elinle kaldır, dirseği geriye çek.',
      'Üstte 1 saniye sık.',
      'Yavaşça indir; sonra tarafı değiştir.',
    ],
    tips: ['Gövdeni döndürme.'],
  ),
  Exercise(
    id: 'seated_row', name: 'Oturarak Kablo Row', muscle: Muscle.back,
    equipment: Equipment.cable, level: Level.beginner, sets: 3, reps: 12, restSec: 60,
    steps: [
      'Ayaklarını platforma koy, dizler hafif bükük otur.',
      'Sapı karnına doğru çek, kürek kemiklerini birleştir.',
      'Bir saniye bekle.',
      'Kolları kontrollü uzat.',
    ],
    tips: ['Öne arkaya sallanma.'],
  ),
  Exercise(
    id: 'superman', name: 'Superman', muscle: Muscle.back,
    equipment: Equipment.none, level: Level.beginner, sets: 3, reps: 12, restSec: 30,
    steps: [
      'Yüzüstü uzan, kollarını öne uzat.',
      'Kollarını, göğsünü ve bacaklarını aynı anda yerden kaldır.',
      '2 saniye bekle.',
      'Yavaşça indir.',
    ],
    tips: ['Boynunu zorlama; bakışın yere doğru olsun.'],
  ),
  // ── OMUZ ───────────────────────────────────────────────────────────────
  Exercise(
    id: 'shoulder_press', name: 'Dambıl Omuz Press', muscle: Muscle.shoulders,
    equipment: Equipment.dumbbell, level: Level.beginner, sets: 3, reps: 10, restSec: 75,
    steps: [
      'Otur veya dik dur; dambılları omuz hizasında tut.',
      'Dambılları başının üstüne doğru it.',
      'Üstte kollar tam uzasın.',
      'Yavaşça omuz hizasına indir.',
    ],
    tips: ['Belini aşırı kavisleme, karnını sık.'],
  ),
  Exercise(
    id: 'lateral_raise', name: 'Yan Omuz Kaldırma', muscle: Muscle.shoulders,
    equipment: Equipment.dumbbell, level: Level.beginner, sets: 3, reps: 15, restSec: 45,
    steps: [
      'Dambılları yanlarda tut, dirsekler hafif bükük.',
      'Kolları omuz hizasına kadar yana kaldır.',
      'Üstte kısa dur.',
      'Yavaşça indir.',
    ],
    tips: ['Hafif ağırlıkla yap, sallanma.'],
  ),
  Exercise(
    id: 'pike_pushup', name: 'Pike Şınav', muscle: Muscle.shoulders,
    equipment: Equipment.none, level: Level.intermediate, sets: 3, reps: 8, restSec: 60,
    steps: [
      'Kalçanı yukarı kaldırıp ters V pozisyonu al.',
      'Başının tepesini yere doğru indir, dirsekler bükülsün.',
      'Omuzlarınla iterek yukarı çık.',
    ],
    tips: ['Bacaklar düz, kalça yüksekte kalsın.'],
  ),
  // ── KOL ────────────────────────────────────────────────────────────────
  Exercise(
    id: 'bicep_curl', name: 'Dambıl Biceps Curl', muscle: Muscle.arms,
    equipment: Equipment.dumbbell, level: Level.beginner, sets: 3, reps: 12, restSec: 45,
    steps: [
      'Dambılları yanlarda avuçlar öne bakacak şekilde tut.',
      'Dirsekleri sabit tutarak dambılları omuza kıvır.',
      'Üstte sık.',
      'Yavaşça indir.',
    ],
    tips: ['Dirsekler gövdeye yapışık kalsın.'],
  ),
  Exercise(
    id: 'tricep_dips', name: 'Sehpada Dips', muscle: Muscle.arms,
    equipment: Equipment.none, level: Level.beginner, sets: 3, reps: 12, restSec: 45,
    steps: [
      'Ellerini sehpa kenarına koy, bacaklar öne uzansın.',
      'Dirsekleri bükerek kalçanı aşağı indir.',
      'Dirseklerin arkaya baksın.',
      'Triceps ile yukarı it.',
    ],
    tips: ['Omuzlarını kulaklarından uzak tut.'],
  ),
  Exercise(
    id: 'tricep_pushdown', name: 'Kablo Triceps Pushdown', muscle: Muscle.arms,
    equipment: Equipment.cable, level: Level.beginner, sets: 3, reps: 12, restSec: 45,
    steps: [
      'Üst makarada sapı tut, dirsekler gövdeye yapışık.',
      'Kolları aşağı doğru tam uzat.',
      'Bir saniye sık.',
      'Yavaşça yukarı bırak.',
    ],
    tips: ['Sadece ön kol hareket etsin.'],
  ),
  Exercise(
    id: 'hammer_curl', name: 'Hammer Curl', muscle: Muscle.arms,
    equipment: Equipment.dumbbell, level: Level.beginner, sets: 3, reps: 12, restSec: 45,
    steps: [
      'Dambılları avuçlar içe bakacak şekilde tut.',
      'Dirsekleri sabitleyip omuza kıvır.',
      'Yavaşça indir.',
    ],
    tips: ['Ön kolu da çalıştırır; sallanma.'],
  ),
  // ── BACAK ──────────────────────────────────────────────────────────────
  Exercise(
    id: 'squat', name: 'Squat', muscle: Muscle.legs,
    equipment: Equipment.none, level: Level.beginner, sets: 3, reps: 15, restSec: 45,
    steps: [
      'Ayaklar omuz genişliğinde, parmaklar hafif dışa.',
      'Kalçanı geriye iterek otur gibi in.',
      'Uyluklar yere paralel olunca dur.',
      'Topuklarından iterek kalk.',
    ],
    tips: ['Dizler ayak parmaklarını geçmesin, sırtın dik kalsın.'],
  ),
  Exercise(
    id: 'back_squat', name: 'Barbell Squat', muscle: Muscle.legs,
    equipment: Equipment.barbell, level: Level.intermediate, sets: 4, reps: 8, restSec: 120,
    steps: [
      'Barı üst sırtına (trapez) yerleştir, rafından çık.',
      'Göğsün dik, bakış karşıda; kalçayı geriye iterek in.',
      'Uyluklar paralel veya biraz altına kadar in.',
      'Topuklarından iterek yüksel.',
    ],
    tips: ['Ağır setlerde güvenlik pimleri ve yardımcı kullan.', 'Dizler içe kaçmasın.'],
  ),
  Exercise(
    id: 'leg_press', name: 'Leg Press', muscle: Muscle.legs,
    equipment: Equipment.machine, level: Level.beginner, sets: 3, reps: 12, restSec: 90,
    steps: [
      'Sırtını koltuğa yasla, ayakları platformda omuz genişliğinde tut.',
      'Platformu dizler 90° olana kadar indir.',
      'Topuklarından iterek uzat; dizleri tam kilitleme.',
    ],
    tips: ['Kalçanı koltuktan kaldırma.'],
  ),
  Exercise(
    id: 'lunge', name: 'Lunge (Hamle)', muscle: Muscle.legs,
    equipment: Equipment.none, level: Level.beginner, sets: 3, reps: 12, restSec: 45,
    steps: [
      'Dik dur, bir adım öne at.',
      'Arka diz yere yaklaşana kadar in.',
      'Ön ayakla iterek başlangıca dön.',
      'Bacak değiştir.',
    ],
    tips: ['Ön diz ayak ucunun hizasını geçmesin.'],
  ),
  Exercise(
    id: 'rdl', name: 'Romanian Deadlift', muscle: Muscle.legs,
    equipment: Equipment.barbell, level: Level.intermediate, sets: 3, reps: 10, restSec: 90,
    steps: [
      'Barı kalça önünde tut, dizler hafif bükük.',
      'Kalçanı geriye iterek barı bacaklara yakın indir.',
      'Arka uyluğunda gerilmeyi hissedince dur.',
      'Kalçanı öne iterek kalk.',
    ],
    tips: ['Sırt hep düz; bar bacağa yakın.'],
  ),
  Exercise(
    id: 'glute_bridge', name: 'Glute Bridge', muscle: Muscle.legs,
    equipment: Equipment.none, level: Level.beginner, sets: 3, reps: 15, restSec: 30,
    steps: [
      'Sırtüstü yat, dizler bükük, ayaklar yerde.',
      'Kalçanı omuzlarınla diz hizası düz çizgi olana kadar kaldır.',
      'Üstte kalçanı sık.',
      'Yavaşça indir.',
    ],
    tips: ['Beli değil kalçayı kullan.'],
  ),
  Exercise(
    id: 'calf_raise', name: 'Baldır Kaldırma', muscle: Muscle.legs,
    equipment: Equipment.none, level: Level.beginner, sets: 3, reps: 20, restSec: 30,
    steps: [
      'Ayakta dur, bir yere tutunabilirsin.',
      'Parmak uçlarında yüksel.',
      'Üstte 1 saniye bekle, yavaşça in.',
    ],
    tips: ['Basamak kenarında yaparsan hareket açıklığı artar.'],
  ),
  // ── KARIN ──────────────────────────────────────────────────────────────
  Exercise(
    id: 'plank', name: 'Plank', muscle: Muscle.core,
    equipment: Equipment.none, level: Level.beginner, sets: 3, reps: 1, durationSec: 40, restSec: 30,
    steps: [
      'Dirsekler omuz altında, ön kollar yerde.',
      'Vücudunu baştan topuğa düz tut.',
      'Karnını ve kalçanı sık, nefes almaya devam et.',
    ],
    tips: ['Kalçan yukarı çıkmasın veya çökmesin.'],
  ),
  Exercise(
    id: 'crunch', name: 'Crunch', muscle: Muscle.core,
    equipment: Equipment.none, level: Level.beginner, sets: 3, reps: 15, restSec: 30,
    steps: [
      'Sırtüstü yat, dizler bükük, eller kulak arkasında.',
      'Omuzlarını yerden kaldırarak karnını sık.',
      'Yavaşça in.',
    ],
    tips: ['Boynunu çekme; hareket karından gelsin.'],
  ),
  Exercise(
    id: 'bicycle_crunch', name: 'Bicycle Crunch', muscle: Muscle.core,
    equipment: Equipment.none, level: Level.intermediate, sets: 3, reps: 20, restSec: 30,
    steps: [
      'Sırtüstü yat, bacakları havada, eller kulak arkasında.',
      'Sağ dirseği sol dize götür, sağ bacak uzansın.',
      'Yön değiştir; bisiklet çevirir gibi devam et.',
    ],
    tips: ['Yavaş ve kontrollü yap.'],
  ),
  Exercise(
    id: 'leg_raise', name: 'Bacak Kaldırma', muscle: Muscle.core,
    equipment: Equipment.none, level: Level.intermediate, sets: 3, reps: 12, restSec: 45,
    steps: [
      'Sırtüstü yat, ellerini kalçanın altına koy.',
      'Bacakları düz şekilde 90°ye kaldır.',
      'Yavaşça yere yaklaştır ama değdirme.',
    ],
    tips: ['Belin yerden kalkıyorsa dizlerini bük.'],
  ),
  Exercise(
    id: 'russian_twist', name: 'Russian Twist', muscle: Muscle.core,
    equipment: Equipment.none, level: Level.intermediate, sets: 3, reps: 20, restSec: 30,
    steps: [
      'Otur, gövdeni hafif geriye yatır, ayaklar havada veya yerde.',
      'Ellerini birleştirip gövdeni sağa sonra sola döndür.',
    ],
    tips: ['Dönüşü omuzlarla değil gövdeyle yap.'],
  ),
  Exercise(
    id: 'mountain_climber', name: 'Mountain Climber', muscle: Muscle.core,
    equipment: Equipment.none, level: Level.beginner, sets: 3, reps: 1, durationSec: 40, restSec: 20,
    steps: [
      'Şınav pozisyonuna geç.',
      'Dizlerini sırayla hızlıca göğsüne çek.',
      'Kalçanı sabit, karnını sıkı tut.',
    ],
    tips: ['Nefesini düzenli tut.'],
  ),
  // ── TÜM VÜCUT / KARDİYO ────────────────────────────────────────────────
  Exercise(
    id: 'burpee', name: 'Burpee', muscle: Muscle.fullBody,
    equipment: Equipment.none, level: Level.intermediate, sets: 3, reps: 10, restSec: 45,
    steps: [
      'Ayakta başla, çömelip ellerini yere koy.',
      'Bacaklarını arkaya atıp şınav pozisyonuna gel.',
      'Bacaklarını geri çek ve zıplayarak kalk.',
    ],
    tips: ['Tempoyu değil formu koru.'],
  ),
  Exercise(
    id: 'jumping_jacks', name: 'Jumping Jacks', muscle: Muscle.cardio,
    equipment: Equipment.none, level: Level.beginner, sets: 3, reps: 1, durationSec: 40, restSec: 20,
    steps: [
      'Ayaklar bitişik, kollar yanlarda başla.',
      'Zıplayarak ayakları aç, kolları başın üstünde birleştir.',
      'Zıplayarak başlangıca dön.',
    ],
    tips: ['Yumuşak in, dizlerini koru.'],
  ),
  Exercise(
    id: 'high_knees', name: 'High Knees', muscle: Muscle.cardio,
    equipment: Equipment.none, level: Level.beginner, sets: 3, reps: 1, durationSec: 40, restSec: 20,
    steps: [
      'Olduğun yerde koşarak dizlerini kalça hizasına çek.',
      'Kollarını koşar gibi salla.',
    ],
    tips: ['Ayak ucuyla yumuşak bas.'],
  ),
  Exercise(
    id: 'jump_squat', name: 'Zıplamalı Squat', muscle: Muscle.fullBody,
    equipment: Equipment.none, level: Level.intermediate, sets: 3, reps: 12, restSec: 45,
    steps: [
      'Normal squat pozisyonuna in.',
      'Patlayıcı şekilde yukarı zıpla.',
      'Dizlerini bükerek yumuşak in.',
    ],
    tips: ['Diz sorunun varsa normal squat yap.'],
  ),
  Exercise(
    id: 'treadmill_run', name: 'Koşu Bandı (Aralıklı)', muscle: Muscle.cardio,
    equipment: Equipment.machine, level: Level.beginner, sets: 1, reps: 1, durationSec: 1200, restSec: 0,
    steps: [
      '3 dk yürüyüş tempo ile ısın.',
      '1 dk hızlı koş, 2 dk yürü; 5 tur tekrarla.',
      '2 dk yavaş yürüyerek soğu.',
    ],
    tips: ['Konuşabildiğin tempoda başla.'],
  ),
  Exercise(
    id: 'rowing', name: 'Kürek Makinesi', muscle: Muscle.cardio,
    equipment: Equipment.machine, level: Level.beginner, sets: 1, reps: 1, durationSec: 600, restSec: 0,
    steps: [
      'Önce bacaklarınla it, sonra gövdeni arkaya yatır, en son kolları çek.',
      'Dönüşte sırayla tersini yap: kollar, gövde, bacaklar.',
    ],
    tips: ['Sırtını yuvarlama; güç bacaktan gelir.'],
  ),
  // ── ESNEME ─────────────────────────────────────────────────────────────
  Exercise(
    id: 'child_pose', name: 'Çocuk Pozu', muscle: Muscle.back,
    equipment: Equipment.none, level: Level.beginner, sets: 1, reps: 1, durationSec: 40, restSec: 10,
    steps: [
      'Dizlerinin üzerine otur, kalçanı topuklarına bırak.',
      'Kollarını öne uzatıp alnını yere yaklaştır.',
      'Derin nefes al.',
    ],
    tips: ['Sırt ve bel gerginliği için idealdir.'],
  ),
  Exercise(
    id: 'cat_cow', name: 'Kedi-İnek', muscle: Muscle.core,
    equipment: Equipment.none, level: Level.beginner, sets: 1, reps: 1, durationSec: 40, restSec: 10,
    steps: [
      'Dört ayak pozisyonuna gel.',
      'Nefes verirken sırtını yuvarla, çeneni göğsüne yaklaştır.',
      'Nefes alırken belini çukurlaştırıp başını kaldır.',
    ],
    tips: ['Yavaş ve nefesle uyumlu ilerle.'],
  ),
  Exercise(
    id: 'hamstring_stretch', name: 'Arka Bacak Esnetme', muscle: Muscle.legs,
    equipment: Equipment.none, level: Level.beginner, sets: 1, reps: 1, durationSec: 40, restSec: 10,
    steps: [
      'Oturup bir bacağını öne uzat, diğerini bük.',
      'Dik sırtla uzanan ayağına doğru eğil.',
      'Gerilmeyi hisset, 40 saniye bekle; tarafı değiştir.',
    ],
    tips: ['Sıçrama yapma, acı değil hafif gerilme hisset.'],
  ),
  Exercise(
    id: 'hip_flexor', name: 'Kalça Fleksör Esnetme', muscle: Muscle.legs,
    equipment: Equipment.none, level: Level.beginner, sets: 1, reps: 1, durationSec: 40, restSec: 10,
    steps: [
      'Bir dizin üzerinde dik çök, diğer ayak önde.',
      'Kalçanı hafifçe öne it.',
      'Arka bacağının ön kalçasında gerilme hisset; tarafı değiştir.',
    ],
    tips: ['Belini kavisleme.'],
  ),
  Exercise(
    id: 'shoulder_stretch', name: 'Omuz Esnetme', muscle: Muscle.shoulders,
    equipment: Equipment.none, level: Level.beginner, sets: 1, reps: 1, durationSec: 30, restSec: 10,
    steps: [
      'Bir kolunu göğsünün önünden karşıya uzat.',
      'Diğer kolunla gövdene doğru hafifçe çek.',
      'Süre dolunca kol değiştir.',
    ],
    tips: ['Omzunu yukarı kaldırma.'],
  ),
];

final Map<String, Exercise> _byId = {for (final e in exerciseLibrary) e.id: e};

Exercise exerciseById(String id) => _byId[id]!;
