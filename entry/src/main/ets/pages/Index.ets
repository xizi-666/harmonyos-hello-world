/**
 * 参考文献格式检查器 - 主界面（PC 三栏布局）
 * 左栏：条目列表与管理；中栏：条目编辑表单；右栏：格式预览、批量格式化、检查结果
 */
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { pasteboard } from '@kit.BasicServicesKit';
import {
  Citation,
  CitationType,
  TYPE_LIST,
  STYLE_LIST,
  TypeMeta,
  buildIssues,
  deserializeList,
  fieldLabel,
  findDuplicateIds,
  formatCitation,
  formatList,
  missingFields,
  sampleCitations,
  serializeList,
  typeLabelOf
} from '../model/CitationData';

const COLOR_BG: string = '#F1F3F6';
const COLOR_CARD: string = '#FFFFFF';
const COLOR_PRIMARY: string = '#007DFF';
const COLOR_TEXT: string = '#182431';
const COLOR_SUB: string = '#86909C';
const COLOR_BORDER: string = '#E5E9F0';
const COLOR_RED: string = '#FA5151';
const COLOR_RED_BG: string = '#FEF0EF';
const COLOR_ORANGE: string = '#FF8F1F';
const COLOR_ORANGE_BG: string = '#FFF6E9';
const COLOR_GREEN: string = '#34C759';
const COLOR_GREEN_BG: string = '#EBFAEF';

@Entry
@Component
struct Index {
  @State citations: Citation[] = [];
  @State keyword: string = '';
  @State selectedId: number = -1;
  @State checkedIds: number[] = [];
  @State styleIndex: number = 0;
  @State msg: string = '';
  // 表单字段
  @State formType: CitationType = 'journal';
  @State formAuthors: string = '';
  @State formTitle: string = '';
  @State formYear: string = '';
  @State formSource: string = '';
  @State formCity: string = '';
  @State formVolume: string = '';
  @State formIssue: string = '';
  @State formPages: string = '';
  @State formDoi: string = '';
  @State formUrl: string = '';

  aboutToAppear(): void {
    this.loadStore();
  }

  // ==================== 数据持久化 ====================

  /** 由 EntryAbility 读取本地数据后经 AppStorage 传入 */
  loadStore(): void {
    const cached: string | undefined = AppStorage.get<string>('citations_raw');
    const raw: string = cached === undefined ? '' : cached;
    if (raw.length > 0) {
      this.citations = deserializeList(raw);
    } else {
      this.citations = sampleCitations();
      this.persist();
    }
    if (this.citations.length > 0) {
      this.selectedId = this.citations[0].id;
      this.loadToForm(this.citations[0]);
    }
  }

  persist(): void {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      preferences.getPreferences(ctx, 'ref_store').then((pref: preferences.Preferences) => {
        pref.put('citations_v1', serializeList(this.citations)).then(() => {
          pref.flush();
        });
      });
    } catch (e) {
      this.showMsg('本地保存失败');
    }
  }

  // ==================== 状态辅助方法 ====================

  showMsg(text: string): void {
    this.msg = text;
    setTimeout(() => {
      this.msg = '';
    }, 2500);
  }

  filtered(): Citation[] {
    const kw: string = this.keyword.trim().toLowerCase();
    if (kw.length === 0) {
      return this.citations;
    }
    const result: Citation[] = [];
    for (let i = 0; i < this.citations.length; i++) {
      const c: Citation = this.citations[i];
      if (c.title.toLowerCase().indexOf(kw) >= 0 || c.authors.toLowerCase().indexOf(kw) >= 0 ||
        c.source.toLowerCase().indexOf(kw) >= 0 || c.year.indexOf(kw) >= 0) {
        result.push(c);
      }
    }
    return result;
  }

  isMissing(c: Citation): boolean {
    return missingFields(c).length > 0;
  }

  isDuplicate(c: Citation): boolean {
    const ids: number[] = findDuplicateIds(this.citations);
    for (let i = 0; i < ids.length; i++) {
      if (ids[i] === c.id) {
        return true;
      }
    }
    return false;
  }

  missingCount(): number {
    let n = 0;
    for (let i = 0; i < this.citations.length; i++) {
      if (this.isMissing(this.citations[i])) {
        n++;
      }
    }
    return n;
  }

  duplicateCount(): number {
    return findDuplicateIds(this.citations.length > 0 ? this.citations : []).length;
  }

  isChecked(id: number): boolean {
    for (let i = 0; i < this.checkedIds.length; i++) {
      if (this.checkedIds[i] === id) {
        return true;
      }
    }
    return false;
  }

  setChecked(id: number, on: boolean): void {
    if (on) {
      if (!this.isChecked(id)) {
        this.checkedIds.push(id);
      }
    } else {
      const next: number[] = [];
      for (let i = 0; i < this.checkedIds.length; i++) {
        if (this.checkedIds[i] !== id) {
          next.push(this.checkedIds[i]);
        }
      }
      this.checkedIds = next;
    }
  }

  checkedCitations(): Citation[] {
    const result: Citation[] = [];
    for (let i = 0; i < this.citations.length; i++) {
      if (this.isChecked(this.citations[i].id)) {
        result.push(this.citations[i]);
      }
    }
    return result;
  }

  allCheckedVisible(): boolean {
    const list: Citation[] = this.filtered();
    if (list.length === 0) {
      return false;
    }
    for (let i = 0; i < list.length; i++) {
      if (!this.isChecked(list[i].id)) {
        return false;
      }
    }
    return true;
  }

  toggleCheckAll(): void {
    const list: Citation[] = this.filtered();
    if (this.allCheckedVisible()) {
      this.checkedIds = [];
    } else {
      const ids: number[] = [];
      for (let i = 0; i < list.length; i++) {
        ids.push(list[i].id);
      }
      this.checkedIds = ids;
    }
  }

  // ==================== 表单 ====================

  loadToForm(c: Citation): void {
    this.formType = c.type;
    this.formAuthors = c.authors;
    this.formTitle = c.title;
    this.formYear = c.year;
    this.formSource = c.source;
    this.formCity = c.city;
    this.formVolume = c.volume;
    this.formIssue = c.issue;
    this.formPages = c.pages;
    this.formDoi = c.doi;
    this.formUrl = c.url;
  }

  clearForm(): void {
    this.formAuthors = '';
    this.formTitle = '';
    this.formYear = '';
    this.formSource = '';
    this.formCity = '';
    this.formVolume = '';
    this.formIssue = '';
    this.formPages = '';
    this.formDoi = '';
    this.formUrl = '';
  }

  getField(key: string): string {
    if (key === 'authors') {
      return this.formAuthors;
    }
    if (key === 'title') {
      return this.formTitle;
    }
    if (key === 'year') {
      return this.formYear;
    }
    if (key === 'source') {
      return this.formSource;
    }
    if (key === 'city') {
      return this.formCity;
    }
    if (key === 'volume') {
      return this.formVolume;
    }
    if (key === 'issue') {
      return this.formIssue;
    }
    if (key === 'pages') {
      return this.formPages;
    }
    if (key === 'doi') {
      return this.formDoi;
    }
    if (key === 'url') {
      return this.formUrl;
    }
    return '';
  }

  setField(key: string, v: string): void {
    if (key === 'authors') {
      this.formAuthors = v;
    } else if (key === 'title') {
      this.formTitle = v;
    } else if (key === 'year') {
      this.formYear = v;
    } else if (key === 'source') {
      this.formSource = v;
    } else if (key === 'city') {
      this.formCity = v;
    } else if (key === 'volume') {
      this.formVolume = v;
    } else if (key === 'issue') {
      this.formIssue = v;
    } else if (key === 'pages') {
      this.formPages = v;
    } else if (key === 'doi') {
      this.formDoi = v;
    } else if (key === 'url') {
      this.formUrl = v;
    }
  }

  /** 当前类型需要显示的表单字段 */
  visibleFormFields(): string[] {
    if (this.formType === 'journal') {
      return ['authors', 'title', 'year', 'source', 'volume', 'issue', 'pages', 'doi'];
    }
    if (this.formType === 'thesis') {
      return ['authors', 'title', 'year', 'source', 'city'];
    }
    if (this.formType === 'conference') {
      return ['authors', 'title', 'year', 'source', 'city', 'pages', 'doi'];
    }
    if (this.formType === 'book') {
      return ['authors', 'title', 'year', 'source', 'city'];
    }
    return ['authors', 'title', 'year', 'source', 'url'];
  }

  /** source 字段在当前类型下的显示名 */
  sourceFieldLabel(): string {
    if (this.formType === 'journal') {
      return '期刊名称';
    }
    if (this.formType === 'thesis') {
      return '学位授予单位';
    }
    if (this.formType === 'conference') {
      return '会议名称';
    }
    if (this.formType === 'book') {
      return '出版社';
    }
    return '网站名称';
  }

  fieldIsRequired(key: string): boolean {
    const fields: string[] = this.visibleFormFields();
    const requiredMap: Record<string, boolean> = {
      'authors': true,
      'title': true,
      'year': true,
      'source': true,
      'city': true,
      'volume': true,
      'issue': true,
      'pages': true,
      'url': true,
      'doi': false
    };
    let req = false;
    if (requiredMap[key] === true) {
      req = true;
    }
    // 网络资源作者可为空
    if (this.formType === 'web' && key === 'authors') {
      req = false;
    }
    // 会议论文城市为可选
    if (this.formType === 'conference' && key === 'city') {
      req = false;
    }
    if (fields.indexOf(key) < 0) {
      req = false;
    }
    return req;
  }

  fieldLabelText(key: string): string {
    if (key === 'source') {
      return this.sourceFieldLabel();
    }
    return fieldLabel(key);
  }

  /** 由表单构造条目预览对象 */
  citationFromForm(): Citation {
    const c: Citation = {
      id: this.selectedId,
      type: this.formType,
      authors: this.formAuthors,
      title: this.formTitle,
      year: this.formYear,
      source: this.formSource,
      city: this.formCity,
      volume: this.formVolume,
      issue: this.formIssue,
      pages: this.formPages,
      doi: this.formDoi,
      url: this.formUrl
    };
    return c;
  }

  saveForm(): void {
    if (this.formTitle.trim().length === 0) {
      this.showMsg('题名不能为空');
      return;
    }
    const c: Citation = this.citationFromForm();
    if (this.selectedId < 0) {
      let maxId = 0;
      for (let i = 0; i < this.citations.length; i++) {
        if (this.citations[i].id > maxId) {
          maxId = this.citations[i].id;
        }
      }
      c.id = maxId + 1;
      this.citations.push(c);
      this.selectedId = c.id;
      this.showMsg('已新增条目');
    } else {
      const next: Citation[] = [];
      for (let i = 0; i < this.citations.length; i++) {
        if (this.citations[i].id === this.selectedId) {
          next.push(c);
        } else {
          next.push(this.citations[i]);
        }
      }
      this.citations = next;
      this.showMsg('已保存修改');
    }
    this.persist();
  }

  deleteSelected(): void {
    if (this.selectedId < 0) {
      return;
    }
    const next: Citation[] = [];
    for (let i = 0; i < this.citations.length; i++) {
      if (this.citations[i].id !== this.selectedId) {
        next.push(this.citations[i]);
      }
    }
    this.citations = next;
    this.setChecked(this.selectedId, false);
    this.selectedId = -1;
    this.clearForm();
    this.persist();
    this.showMsg('已删除条目');
  }

  selectEntry(id: number): void {
    this.selectedId = id;
    for (let i = 0; i < this.citations.length; i++) {
      if (this.citations[i].id === id) {
        this.loadToForm(this.citations[i]);
        break;
      }
    }
  }

  importSamples(): void {
    if (this.citations.length > 0) {
      this.showMsg('库中已有条目，示例仅在空库时导入');
      return;
    }
    this.citations = sampleCitations();
    if (this.citations.length > 0) {
      this.selectedId = this.citations[0].id;
      this.loadToForm(this.citations[0]);
    }
    this.persist();
    this.showMsg('已导入示例数据');
  }

  // ==================== 剪贴板 ====================

  copyText(text: string, tip: string): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      this.showMsg(tip);
    }).catch(() => {
      this.showMsg('复制失败');
    });
  }

  // ==================== 通用小构件 ====================

  @Builder
  badge(text: string, fg: string, bg: string) {
    Text(text)
      .fontSize(11)
      .fontColor(fg)
      .backgroundColor(bg)
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .borderRadius(4)
  }

  @Builder
  sectionTitle(text: string) {
    Text(text)
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .fontColor(COLOR_TEXT)
      .margin({ top: 14, bottom: 8 })
  }

  @Builder
  formFieldRow(key: string, placeholder: string) {
    Row() {
      Text(this.fieldIsRequired(key) ? '* ' : '')
        .fontSize(14)
        .fontColor(COLOR_RED)
      Text(this.fieldLabelText(key))
        .fontSize(14)
        .fontColor(COLOR_SUB)
        .width(96)
      TextInput({ text: this.getField(key), placeholder: placeholder })
        .fontSize(14)
        .height(38)
        .backgroundColor('#F5F6F8')
        .borderRadius(6)
        .padding({ left: 10, right: 10 })
        .layoutWeight(1)
        .onChange((v: string) => {
          this.setField(key, v);
        })
    }
    .width('100%')
    .margin({ bottom: 10 })
  }

  @Builder
  citationItem(c: Citation) {
    Column() {
      Row() {
        Toggle({ type: ToggleType.Checkbox, isOn: this.isChecked(c.id) })
          .selectedColor(COLOR_PRIMARY)
          .onChange((isOn: boolean) => {
            this.setChecked(c.id, isOn);
          })
          .margin({ right: 8 })
        Column() {
          Text(c.title.trim().length > 0 ? c.title : '（无题名）')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(c.authors + '  ' + c.year + '  ' + c.source)
            .fontSize(12)
            .fontColor(COLOR_SUB)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('[' + typeLabelOf(c.type) + ']')
          .fontSize(11)
          .fontColor(COLOR_SUB)
          .backgroundColor(COLOR_BG)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(4)
          .margin({ left: 6 })
      }
      .width('100%')
      Row() {
        if (this.isMissing(c)) {
          this.badge('缺字段', COLOR_RED, COLOR_RED_BG)
        }
        if (this.isDuplicate(c)) {
          this.badge('疑似重复', COLOR_ORANGE, COLOR_ORANGE_BG)
        }
        if (!this.isMissing(c) && !this.isDuplicate(c)) {
          this.badge('完整', COLOR_GREEN, COLOR_GREEN_BG)
        }
      }
      .margin({ top: 6, left: 32 })
    }
    .width('100%')
    .padding(12)
    .borderRadius(8)
    .backgroundColor(this.selectedId === c.id ? '#EBF3FF' : COLOR_CARD)
    .border({
      width: this.selectedId === c.id ? 1.5 : 1,
      color: this.selectedId === c.id ? COLOR_PRIMARY : COLOR_BORDER
    })
    .margin({ bottom: 8 })
    .onClick(() => {
      this.selectEntry(c.id);
    })
  }

  @Builder
  issueLine(text: string, color: string) {
    Text(text)
      .fontSize(12)
      .fontColor(color)
      .lineHeight(18)
      .margin({ bottom: 6 })
  }

  // ==================== 页面 ====================

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('参考文献格式检查器')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
        Text('校园科研助手')
          .fontSize(12)
          .fontColor(COLOR_SUB)
          .margin({ left: 10 })
        Blank()
        Row() {
          Text('共 ' + this.citations.length + ' 条')
            .fontSize(12)
            .fontColor(COLOR_SUB)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(COLOR_CARD)
            .borderRadius(10)
          Text('缺字段 ' + this.missingCount())
            .fontSize(12)
            .fontColor(this.missingCount() > 0 ? COLOR_RED : COLOR_SUB)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(COLOR_CARD)
            .borderRadius(10)
            .margin({ left: 6 })
          Text('重复 ' + this.duplicateCount())
            .fontSize(12)
            .fontColor(this.duplicateCount() > 0 ? COLOR_ORANGE : COLOR_SUB)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(COLOR_CARD)
            .borderRadius(10)
            .margin({ left: 6 })
          if (this.msg.length > 0) {
            Text(this.msg)
              .fontSize(12)
              .fontColor(COLOR_GREEN)
              .margin({ left: 12 })
          }
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 20, right: 20 })
      .backgroundColor(COLOR_CARD)
      .border({ width: { bottom: 1 }, color: COLOR_BORDER })

      // 三栏主体
      Row() {
        // ============ 左栏：条目管理 ============
        Column() {
          TextInput({ placeholder: '搜索题名 / 作者 / 来源 / 年份' })
            .fontSize(13)
            .height(36)
            .backgroundColor(COLOR_CARD)
            .borderRadius(6)
            .padding({ left: 10, right: 10 })
            .onChange((v: string) => {
              this.keyword = v;
            })
          Row() {
            Button('新建条目')
              .fontSize(13)
              .height(32)
              .backgroundColor(COLOR_PRIMARY)
              .onClick(() => {
                this.selectedId = -1;
                this.clearForm();
              })
            Button('导入示例')
              .fontSize(13)
              .height(32)
              .backgroundColor('#EAF1FF')
              .fontColor(COLOR_PRIMARY)
              .margin({ left: 8 })
              .onClick(() => {
                this.importSamples();
              })
            Blank()
            Toggle({ type: ToggleType.Checkbox, isOn: this.allCheckedVisible() })
              .selectedColor(COLOR_PRIMARY)
              .onChange((isOn: boolean) => {
                this.toggleCheckAll();
              })
            Text('全选')
              .fontSize(12)
              .fontColor(COLOR_SUB)
              .margin({ left: 4 })
          }
          .width('100%')
          .margin({ top: 10, bottom: 10 })

          if (this.citations.length === 0) {
            Column() {
              Text('暂无条目')
                .fontSize(13)
                .fontColor(COLOR_SUB)
                .margin({ top: 40 })
              Text('点击「导入示例」快速体验')
                .fontSize(12)
                .fontColor(COLOR_SUB)
                .margin({ top: 8 })
            }
            .width('100%')
            .layoutWeight(1)
          } else {
            Scroll() {
              Column() {
                ForEach(this.filtered(), (c: Citation) => {
                  this.citationItem(c)
                }, (c: Citation) => c.id.toString() + '_' + c.title + '_' + c.source + '_' + (this.isMissing(c) ? '1' : '0') + (this.isDuplicate(c) ? '1' : '0') + (this.selectedId === c.id ? 's' : '') + (this.isChecked(c.id) ? 'c' : ''))
              }
              .width('100%')
            }
            .layoutWeight(1)
            .scrollBar(BarState.Auto)
          }
        }
        .width(320)
        .height('100%')
        .padding(12)

        // 分隔线
        Divider()
          .vertical(true)
          .height('100%')
          .color(COLOR_BORDER)

        // ============ 中栏：编辑表单 ============
        Scroll() {
          Column() {
            Row() {
              Text(this.selectedId < 0 ? '新建条目' : '编辑条目')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(COLOR_TEXT)
              Blank()
              if (this.selectedId >= 0) {
                Button('删除')
                  .fontSize(13)
                  .height(30)
                  .backgroundColor(COLOR_RED_BG)
                  .fontColor(COLOR_RED)
                  .onClick(() => {
                    this.deleteSelected();
                  })
              }
            }
            .width('100%')
            .margin({ bottom: 14 })

            Text('文献类型')
              .fontSize(14)
              .fontColor(COLOR_SUB)
              .margin({ bottom: 8 })
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(TYPE_LIST, (m: TypeMeta) => {
                Text(m.label)
                  .fontSize(13)
                  .fontColor(this.formType === m.type ? Color.White : COLOR_TEXT)
                  .backgroundColor(this.formType === m.type ? COLOR_PRIMARY : COLOR_CARD)
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .borderRadius(14)
                  .border({ width: 1, color: this.formType === m.type ? COLOR_PRIMARY : COLOR_BORDER })
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => {
                    this.formType = m.type;
                  })
              }, (m: TypeMeta) => m.type)
            }
            .width('100%')
            .margin({ bottom: 6 })

            ForEach(this.visibleFormFields(), (key: string) => {
              this.formFieldRow(key, '请输入' + this.fieldLabelText(key))
            }, (key: string) => key + '_' + this.formType)

            Text('说明：标 * 为该类型文献的建议完整字段，缺失项会在左侧列表和右侧「检查结果」中标红提示。')
              .fontSize(12)
              .fontColor(COLOR_SUB)
              .margin({ top: 4, bottom: 12 })

            Row() {
              Button('保存')
                .fontSize(14)
                .height(36)
                .width(110)
                .backgroundColor(COLOR_PRIMARY)
                .onClick(() => {
                  this.saveForm();
                })
              Button('清空表单')
                .fontSize(14)
                .height(36)
                .width(110)
                .backgroundColor('#F0F2F5')
                .fontColor(COLOR_TEXT)
                .margin({ left: 12 })
                .onClick(() => {
                  this.clearForm();
                })
            }
            .margin({ top: 6, bottom: 20 })
          }
          .width('100%')
          .padding(20)
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .height('100%')
        .scrollBar(BarState.Auto)

        // 分隔线
        Divider()
          .vertical(true)
          .height('100%')
          .color(COLOR_BORDER)

        // ============ 右栏：格式预览 / 批量 / 检查 ============
        Scroll() {
          Column() {
            this.sectionTitle('引用格式预览')

            // 样式切换
            Row() {
              ForEach(STYLE_LIST, (s: string, idx: number) => {
                Text(s)
                  .fontSize(12)
                  .fontColor(this.styleIndex === idx ? Color.White : COLOR_TEXT)
                  .backgroundColor(this.styleIndex === idx ? COLOR_PRIMARY : COLOR_CARD)
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .borderRadius(4)
                  .border({ width: 1, color: this.styleIndex === idx ? COLOR_PRIMARY : COLOR_BORDER })
                  .margin({ right: 6 })
                  .onClick(() => {
                    this.styleIndex = idx;
                  })
              }, (s: string) => s)
            }
            .width('100%')
            .margin({ bottom: 8 })

            Text(this.formTitle.trim().length > 0 ? this.formTitle : '（未命名条目）')
              .fontSize(12)
              .fontColor(COLOR_SUB)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ bottom: 6 })

            Text(formatCitation(this.citationFromForm(), this.styleIndex))
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .lineHeight(20)
              .width('100%')
              .padding(12)
              .backgroundColor(COLOR_CARD)
              .borderRadius(8)
              .border({ width: 1, color: COLOR_BORDER })

            Button('复制此条引用')
              .fontSize(13)
              .height(32)
              .width('100%')
              .backgroundColor('#EAF1FF')
              .fontColor(COLOR_PRIMARY)
              .margin({ top: 8 })
              .onClick(() => {
                this.copyText(formatCitation(this.citationFromForm(), this.styleIndex), '已复制到剪贴板');
              })

            this.sectionTitle('批量格式化（勾选左侧条目）')
            if (this.checkedIds.length === 0) {
              Text('尚未勾选条目。在左侧列表勾选后，这里将按所选样式批量生成参考文献列表。')
                .fontSize(12)
                .fontColor(COLOR_SUB)
                .lineHeight(18)
            } else {
              Text('已勾选 ' + this.checkedIds.length + ' 条，按 ' + STYLE_LIST[this.styleIndex] + ' 生成：')
                .fontSize(12)
                .fontColor(COLOR_SUB)
                .margin({ bottom: 6 })
              Text(formatList(this.checkedCitations(), this.styleIndex))
                .fontSize(12)
                .fontColor(COLOR_TEXT)
                .lineHeight(19)
                .width('100%')
                .padding(12)
                .backgroundColor(COLOR_CARD)
                .borderRadius(8)
                .border({ width: 1, color: COLOR_BORDER })
              Button('复制全部')
                .fontSize(13)
                .height(32)
                .width('100%')
                .backgroundColor(COLOR_PRIMARY)
                .margin({ top: 8 })
                .onClick(() => {
                  this.copyText(formatList(this.checkedCitations(), this.styleIndex), '已复制全部引用');
                })
              Button('取消勾选')
                .fontSize(13)
                .height(32)
                .width('100%')
                .backgroundColor('#F0F2F5')
                .fontColor(COLOR_TEXT)
                .margin({ top: 8 })
                .onClick(() => {
                  this.checkedIds = [];
                })
            }

            this.sectionTitle('检查结果')
            if (this.citations.length === 0) {
              Text('暂无条目可检查。')
                .fontSize(12)
                .fontColor(COLOR_SUB)
            } else if (buildIssues(this.citations).length === 0) {
              Row() {
                this.badge('通过', COLOR_GREEN, COLOR_GREEN_BG)
                Text('所有条目字段完整，未发现重复项。')
                  .fontSize(12)
                  .fontColor(COLOR_SUB)
                  .margin({ left: 6 })
              }
            } else {
              Text('共发现 ' + buildIssues(this.citations).length + ' 个问题：')
                .fontSize(12)
                .fontColor(COLOR_TEXT)
                .margin({ bottom: 6 })
              ForEach(buildIssues(this.citations), (line: string) => {
                this.issueLine(line, line.indexOf('缺字段') >= 0 ? COLOR_RED : COLOR_ORANGE)
              }, (line: string) => line)
            }
          }
          .width('100%')
          .padding(20)
          .alignItems(HorizontalAlign.Start)
        }
        .width(400)
        .height('100%')
        .scrollBar(BarState.Auto)
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor(COLOR_BG)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }
}
