let widgetStorage = new LocalStorage();

interface CourseCardItem {
  courseName: string;
  timeRange: string;
  location: string;
  status: string;
}

@Entry(widgetStorage)
@Component
struct WidgetCard {
  @LocalStorageProp('dateText') dateText: string = '今日课程';
  @LocalStorageProp('generatedAt') generatedAt: string = '--:--';
  @LocalStorageProp('coursesJson') coursesJson: string = '[]';
  @LocalStorageProp('courseCount') courseCount: string = '0';
  @LocalStorageProp('emptyText') emptyText: string = '正在等待课表同步';
  @State private courseList: Array<CourseCardItem> = [];

  aboutToAppear(): void {
    this.parseCourses();
  }

  aboutToReuse(): void {
    this.parseCourses();
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 2 }) {
          Text(this.dateText)
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FBFF');
          Text(`共 ${this.courseCount} 门 · 更新于 ${this.generatedAt}`)
            .fontSize(11)
            .fontColor('#D6E4F0');
        }
        .alignItems(HorizontalAlign.Start)

        Blank();

        Text('NWPU')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F4F8FC')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor('#26FFFFFF')
          .borderRadius(12);
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center);

      if (this.courseList.length === 0) {
        Column({ space: 8 }) {
          Text('今天节奏舒缓')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF');
          Text(this.emptyText)
            .fontSize(12)
            .fontColor('#D9E7F2')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 2, right: 2, top: 8, bottom: 8 });
      } else {
        List({ space: 6 }) {
          ForEach(this.courseList.slice(0, 4), (course: CourseCardItem, index: number) => {
            ListItem() {
              Column({ space: 8 }) {
                Row() {
                  Column({ space: 2 }) {
                    Text(course.courseName)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#FFFFFF')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis });

                    Text(`${course.timeRange}  |  ${course.location}`)
                      .fontSize(11)
                      .fontColor('#D4E0EB')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis });
                  }
                  .alignItems(HorizontalAlign.Start)

                  Blank();

                  Text(this.statusLabel(course.status))
                    .fontSize(10)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.statusTextColor(course.status))
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor(this.statusBadgeColor(course.status))
                    .borderRadius(999);
                }
                .width('100%');

                if (index < Math.min(this.courseList.length, 4) - 1) {
                  Divider()
                    .strokeWidth(1)
                    .color('#20FFFFFF');
                }
              }
              .padding(10)
              .backgroundColor(this.cardColor(course.status))
              .borderRadius(18)
              .backdropBlur(24);
            }
          }, (course: CourseCardItem, index: number) => `${course.courseName}-${course.timeRange}-${index}`)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off);
      }
    }
    .padding(14)
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 145,
      colors: [['#203A43', 0.0], ['#2C5364', 0.48], ['#0F2027', 1.0]]
    })
    .borderRadius(24)
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
    .shadow({
      radius: 18,
      color: '#22000000',
      offsetX: 0,
      offsetY: 10
    });
  }

  private parseCourses(): void {
    try {
      const parsed = JSON.parse(this.coursesJson) as Array<CourseCardItem>;
      this.courseList = Array.isArray(parsed) ? parsed : [];
    } catch (_) {
      this.courseList = [];
    }
  }

  private cardColor(status: string): string {
    return status === 'finished' ? '#14FFFFFF' : '#1FFFFFFF';
  }

  private statusBadgeColor(status: string): string {
    return status === 'finished' ? '#28A0A8B8' : '#2D52C1A8';
  }

  private statusTextColor(status: string): string {
    return status === 'finished' ? '#C4D0DB' : '#DAFFF6';
  }

  private statusLabel(status: string): string {
    return status === 'finished' ? '已上' : '未上';
  }
}
