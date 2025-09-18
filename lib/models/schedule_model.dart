class Schedule {
  final String courseTitle;
  final String courseCode;
  final Instructor instructor;
  final String room;
  final String startTime;
  final String endTime;
  final String semesterStartDate;
  final String semesterEndDate;
  final Section section;
  final Days days;

  Schedule({
    required this.courseTitle,
    required this.courseCode,
    required this.instructor,
    required this.room,
    required this.startTime,
    required this.endTime,
    required this.semesterStartDate,
    required this.semesterEndDate,
    required this.section,
    required this.days,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      courseTitle: json['courseTitle'] ?? '',
      courseCode: json['courseCode'] ?? '',
      instructor: Instructor.fromJson(json['instructor'] ?? {}),
      room: json['room'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      semesterStartDate: json['semesterStartDate'] ?? '',
      semesterEndDate: json['semesterEndDate'] ?? '',
      section: Section.fromJson(json['section'] ?? {}),
      days: Days.fromJson(json['days'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseTitle': courseTitle,
      'courseCode': courseCode,
      'instructor': {
        'first_name': instructor.firstName,
        'last_name': instructor.lastName,
      },
      'room': room,
      'startTime': startTime,
      'endTime': endTime,
      'semesterStartDate': semesterStartDate,
      'semesterEndDate': semesterEndDate,
      'section': {
        'sectionName': section.sectionName,
      },
      'days': {
        'mon': days.mon,
        'tue': days.tue,
        'wed': days.wed,
        'thu': days.thu,
        'fri': days.fri,
        'sat': days.sat,
        'sun': days.sun,
      },
    };
  }
}

class Instructor {
  final String firstName;
  final String lastName;

  Instructor({required this.firstName, required this.lastName});

  factory Instructor.fromJson(Map<String, dynamic> json) {
    return Instructor(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
    );
  }
}

class Section {
  final String sectionName;

  Section({required this.sectionName});

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      sectionName: json['sectionName'] ?? '',
    );
  }
}

class Days {
  final bool mon;
  final bool tue;
  final bool wed;
  final bool thu;
  final bool fri;
  final bool sat;
  final bool sun;

  Days({
    required this.mon,
    required this.tue,
    required this.wed,
    required this.thu,
    required this.fri,
    required this.sat,
    required this.sun,
  });

  factory Days.fromJson(Map<String, dynamic> json) {
    return Days(
      mon: json['mon'] ?? false,
      tue: json['tue'] ?? false,
      wed: json['wed'] ?? false,
      thu: json['thu'] ?? false,
      fri: json['fri'] ?? false,
      sat: json['sat'] ?? false,
      sun: json['sun'] ?? false,
    );
  }
}
