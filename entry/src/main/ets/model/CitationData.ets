/**
 * 参考文献格式检查器 - 数据模型与核心逻辑
 * 功能：引用条目维护、缺字段检查、重复项检查、多种引用格式批量生成
 */

export type CitationType = 'journal' | 'thesis' | 'conference' | 'book' | 'web';

export interface Citation {
  id: number;
  type: CitationType;
  authors: string;
  title: string;
  year: string;
  source: string; // 期刊名 / 学位授予单位 / 会议名 / 出版社 / 网站名
  city: string;   // 出版城市
  volume: string;
  issue: string;
  pages: string;
  doi: string;
  url: string;
}

export interface TypeMeta {
  type: CitationType;
  label: string;
  tag: string;
}

export const TYPE_LIST: TypeMeta[] = [
  { type: 'journal', label: '期刊论文', tag: 'J' },
  { type: 'thesis', label: '学位论文', tag: 'D' },
  { type: 'conference', label: '会议论文', tag: 'C' },
  { type: 'book', label: '图书专著', tag: 'M' },
  { type: 'web', label: '网络资源', tag: 'EB/OL' }
];

export const STYLE_LIST: string[] = ['GB/T 7714', 'APA 第7版', 'MLA 第9版'];

function emptyCitation(id: number): Citation {
  return {
    id: id,
    type: 'journal',
    authors: '',
    title: '',
    year: '',
    source: '',
    city: '',
    volume: '',
    issue: '',
    pages: '',
    doi: '',
    url: ''
  };
}

export function typeMetaOf(t: CitationType): TypeMeta {
  for (let i = 0; i < TYPE_LIST.length; i++) {
    if (TYPE_LIST[i].type === t) {
      return TYPE_LIST[i];
    }
  }
  return TYPE_LIST[0];
}

export function typeLabelOf(t: CitationType): string {
  return typeMetaOf(t).label;
}

/** 各类型文献的必填字段 */
export function requiredFields(t: CitationType): string[] {
  if (t === 'journal') {
    return ['authors', 'title', 'year', 'source', 'volume', 'issue', 'pages'];
  }
  if (t === 'thesis') {
    return ['authors', 'title', 'year', 'source', 'city'];
  }
  if (t === 'conference') {
    return ['authors', 'title', 'year', 'source', 'pages'];
  }
  if (t === 'book') {
    return ['authors', 'title', 'year', 'source', 'city'];
  }
  return ['title', 'year', 'url'];
}

/** 字段中文名 */
export function fieldLabel(f: string): string {
  if (f === 'authors') {
    return '作者';
  }
  if (f === 'title') {
    return '题名';
  }
  if (f === 'year') {
    return '年份';
  }
  if (f === 'source') {
    return '来源';
  }
  if (f === 'city') {
    return '城市';
  }
  if (f === 'volume') {
    return '卷';
  }
  if (f === 'issue') {
    return '期';
  }
  if (f === 'pages') {
    return '页码';
  }
  if (f === 'doi') {
    return 'DOI';
  }
  if (f === 'url') {
    return '网址';
  }
  return f;
}

/** 检查单个条目的缺失字段，返回字段名列表 */
export function missingFields(c: Citation): string[] {
  const req: string[] = requiredFields(c.type);
  const result: string[] = [];
  for (let i = 0; i < req.length; i++) {
    const key: string = req[i];
    let v: string = '';
    if (key === 'authors') {
      v = c.authors;
    } else if (key === 'title') {
      v = c.title;
    } else if (key === 'year') {
      v = c.year;
    } else if (key === 'source') {
      v = c.source;
    } else if (key === 'city') {
      v = c.city;
    } else if (key === 'volume') {
      v = c.volume;
    } else if (key === 'issue') {
      v = c.issue;
    } else if (key === 'pages') {
      v = c.pages;
    } else if (key === 'doi') {
      v = c.doi;
    } else if (key === 'url') {
      v = c.url;
    }
    if (v.trim().length === 0) {
      result.push(key);
    }
  }
  return result;
}

/** 标题归一化：去除空白与标点、统一小写，用于重复项识别 */
export function normalizeTitle(t: string): string {
  return t.toLowerCase().replace(/[\s\p{P}]/gu, '');
}

/** DOI 归一化：去掉常见前缀与大小写差异 */
export function normalizeDoi(d: string): string {
  let v: string = d.trim().toLowerCase();
  if (v.startsWith('https://doi.org/')) {
    v = v.substring('https://doi.org/'.length);
  }
  if (v.startsWith('http://doi.org/')) {
    v = v.substring('http://doi.org/'.length);
  }
  if (v.startsWith('doi:')) {
    v = v.substring('doi:'.length);
  }
  return v;
}

/**
 * 重复项检查：返回重复条目的 id 集合
 * 判定规则：归一化标题相同，或非空 DOI 相同
 */
export function findDuplicateIds(list: Citation[]): number[] {
  const dupIds: number[] = [];
  // 1) 按归一化标题分组
  const titleGroups = new Map<string, number[]>();
  for (let i = 0; i < list.length; i++) {
    const key: string = normalizeTitle(list[i].title);
    if (key.length === 0) {
      continue;
    }
    const group = titleGroups.get(key);
    if (group === undefined) {
      const arr: number[] = [list[i].id];
      titleGroups.set(key, arr);
    } else {
      group.push(list[i].id);
    }
  }
  titleGroups.forEach((ids: number[]) => {
    if (ids.length > 1) {
      for (let k = 0; k < ids.length; k++) {
        dupIds.push(ids[k]);
      }
    }
  });
  // 2) 按 DOI 分组
  const doiGroups = new Map<string, number[]>();
  for (let i = 0; i < list.length; i++) {
    const key: string = normalizeDoi(list[i].doi);
    if (key.length === 0) {
      continue;
    }
    const group = doiGroups.get(key);
    if (group === undefined) {
      const arr: number[] = [list[i].id];
      doiGroups.set(key, arr);
    } else {
      group.push(list[i].id);
    }
  }
  doiGroups.forEach((ids: number[]) => {
    if (ids.length > 1) {
      for (let k = 0; k < ids.length; k++) {
        let exists = false;
        for (let m = 0; m < dupIds.length; m++) {
          if (dupIds[m] === ids[k]) {
            exists = true;
            break;
          }
        }
        if (!exists) {
          dupIds.push(ids[k]);
        }
      }
    }
  });
  return dupIds;
}

/** 解析作者列表（支持中英文逗号、分号分隔） */
function splitAuthors(a: string): string[] {
  const raw: string[] = a.split(/[,，;；]/);
  const result: string[] = [];
  for (let i = 0; i < raw.length; i++) {
    const name: string = raw[i].trim();
    if (name.length > 0) {
      result.push(name);
    }
  }
  return result;
}

/** 判断是否为西文姓名 */
function isLatinName(name: string): boolean {
  return /^[A-Za-z][A-Za-z\s.\-']*$/.test(name.trim());
}

/** GB/T 7714 作者格式：不超过3人全列，超过3人取前3人加“等” */
function formatAuthorsGBT(authors: string): string {
  const arr: string[] = splitAuthors(authors);
  if (arr.length === 0) {
    return '佚名';
  }
  if (arr.length <= 3) {
    return arr.join(', ');
  }
  return arr[0] + ', ' + arr[1] + ', ' + arr[2] + ', 等';
}

/** 西文姓名转 "Last, F. M." 形式 */
function latinToApa(name: string): string {
  const parts: string[] = name.trim().split(/\s+/);
  if (parts.length === 1) {
    return parts[0];
  }
  const last: string = parts[parts.length - 1];
  let initials = '';
  for (let i = 0; i < parts.length - 1; i++) {
    if (parts[i].length > 0) {
      initials += parts[i].substring(0, 1).toUpperCase() + '. ';
    }
  }
  return last + ', ' + initials.trim();
}

/** APA 作者格式：西文姓名转缩写，用 & 连接最后一位 */
function formatAuthorsApa(authors: string): string {
  const arr: string[] = splitAuthors(authors);
  if (arr.length === 0) {
    return 'Anonymous';
  }
  const formatted: string[] = [];
  for (let i = 0; i < arr.length; i++) {
    if (isLatinName(arr[i])) {
      formatted.push(latinToApa(arr[i]));
    } else {
      formatted.push(arr[i]);
    }
  }
  if (formatted.length === 1) {
    return formatted[0];
  }
  let s = '';
  for (let i = 0; i < formatted.length - 1; i++) {
    s += formatted[i] + ', ';
  }
  s += '& ' + formatted[formatted.length - 1];
  return s;
}

/** MLA 作者格式：西文姓名 "Last, First" 反转 */
function latinToMla(name: string): string {
  const parts: string[] = name.trim().split(/\s+/);
  if (parts.length === 1) {
    return parts[0];
  }
  const last: string = parts[parts.length - 1];
  let rest = '';
  for (let i = 0; i < parts.length - 1; i++) {
    rest += parts[i] + ' ';
  }
  return last + ', ' + rest.trim();
}

function formatAuthorsMla(authors: string): string {
  const arr: string[] = splitAuthors(authors);
  if (arr.length === 0) {
    return 'Anonymous';
  }
  const formatted: string[] = [];
  for (let i = 0; i < arr.length; i++) {
    if (isLatinName(arr[i])) {
      formatted.push(latinToMla(arr[i]));
    } else {
      formatted.push(arr[i]);
    }
  }
  if (formatted.length === 1) {
    return formatted[0];
  }
  if (formatted.length === 2) {
    return formatted[0] + ', and ' + formatted[1];
  }
  let s = '';
  for (let i = 0; i < formatted.length - 1; i++) {
    s += formatted[i] + ', ';
  }
  s += 'et al. ' + formatted[formatted.length - 1];
  return s;
}

function joinNonEmpty(parts: string[], sep: string): string {
  const arr: string[] = [];
  for (let i = 0; i < parts.length; i++) {
    if (parts[i].trim().length > 0) {
      arr.push(parts[i].trim());
    }
  }
  return arr.join(sep);
}

function doiUrl(doi: string): string {
  if (doi.trim().length === 0) {
    return '';
  }
  return 'https://doi.org/' + normalizeDoi(doi);
}

/** GB/T 7714-2015 格式化（不含序号） */
export function formatGBT(c: Citation): string {
  const authors: string = formatAuthorsGBT(c.authors);
  const title: string = c.title.trim();
  const tag: string = typeMetaOf(c.type).tag;
  const year: string = c.year.trim();
  if (c.type === 'journal') {
    let vol: string = c.volume.trim().length > 0 ? ', ' + c.volume.trim() : '';
    let iss: string = c.issue.trim().length > 0 ? '(' + c.issue.trim() + ')' : '';
    let pg: string = c.pages.trim().length > 0 ? ': ' + c.pages.trim() : '';
    let doiPart: string = c.doi.trim().length > 0 ? ' ' + doiUrl(c.doi) + '.' : '';
    return authors + '. ' + title + '[' + tag + ']. ' + c.source.trim() + ', ' + year + vol + iss + pg + '.' + doiPart;
  }
  if (c.type === 'thesis') {
    return authors + '. ' + title + '[D]. ' + c.city.trim() + ': ' + c.source.trim() + ', ' + year + '.';
  }
  if (c.type === 'conference') {
    let pg: string = c.pages.trim().length > 0 ? ': ' + c.pages.trim() : '';
    let city: string = c.city.trim().length > 0 ? c.city.trim() + ', ' : '';
    return authors + '. ' + title + '[C]//' + c.source.trim() + '. ' + city + year + pg + '.';
  }
  if (c.type === 'book') {
    return authors + '. ' + title + '[M]. ' + c.city.trim() + ': ' + c.source.trim() + ', ' + year + '.';
  }
  // web
  return authors + '. ' + title + '[EB/OL]. (' + year + '). ' + c.url.trim() + '.';
}

/** APA 第7版格式化 */
export function formatAPA(c: Citation): string {
  const authors: string = formatAuthorsApa(c.authors);
  const title: string = c.title.trim();
  const year: string = c.year.trim().length > 0 ? '(' + c.year.trim() + ')' : '(n.d.)';
  if (c.type === 'journal') {
    let vi: string = '';
    if (c.volume.trim().length > 0 && c.issue.trim().length > 0) {
      vi = ', ' + c.volume.trim() + '(' + c.issue.trim() + ')';
    } else if (c.volume.trim().length > 0) {
      vi = ', ' + c.volume.trim();
    }
    let pg: string = c.pages.trim().length > 0 ? ', ' + c.pages.trim() : '';
    let doiPart: string = c.doi.trim().length > 0 ? ' ' + doiUrl(c.doi) : '';
    return authors + ' ' + year + '. ' + title + '. ' + c.source.trim() + vi + pg + '.' + doiPart;
  }
  if (c.type === 'thesis') {
    return authors + ' ' + year + '. ' + title + ' [学位论文]. ' + c.source.trim() + '.';
  }
  if (c.type === 'conference') {
    let pg: string = c.pages.trim().length > 0 ? ', ' + c.pages.trim() : '';
    return authors + ' ' + year + '. ' + title + ' [会议论文]. ' + c.source.trim() + pg + '.';
  }
  if (c.type === 'book') {
    return authors + ' ' + year + '. ' + title + '. ' + c.source.trim() + '.';
  }
  return authors + ' ' + year + '. ' + title + '. ' + c.url.trim() + '.';
}

/** MLA 第9版格式化 */
export function formatMLA(c: Citation): string {
  const authors: string = formatAuthorsMla(c.authors);
  const title: string = c.title.trim();
  if (c.type === 'journal') {
    let parts: string[] = [];
    parts.push(c.source.trim());
    if (c.volume.trim().length > 0) {
      parts.push('vol. ' + c.volume.trim());
    }
    if (c.issue.trim().length > 0) {
      parts.push('no. ' + c.issue.trim());
    }
    if (c.year.trim().length > 0) {
      parts.push(c.year.trim());
    }
    if (c.pages.trim().length > 0) {
      parts.push('pp. ' + c.pages.trim());
    }
    return authors + '. "' + title + '." ' + joinNonEmpty(parts, ', ') + '.';
  }
  if (c.type === 'thesis') {
    return authors + '. "' + title + '." ' + c.year.trim() + '. ' + c.source.trim() + ', ' + c.city.trim() + '.';
  }
  if (c.type === 'conference') {
    return authors + '. "' + title + '." ' + c.source.trim() + ', ' + c.year.trim() + ', pp. ' + c.pages.trim() + '.';
  }
  if (c.type === 'book') {
    return authors + '. ' + title + '. ' + c.source.trim() + ', ' + c.year.trim() + '.';
  }
  return authors + '. "' + title + '." ' + c.source.trim() + ', ' + c.year.trim() + ', ' + c.url.trim() + '.';
}

/** 按所选样式格式化 */
export function formatCitation(c: Citation, styleIndex: number): string {
  if (styleIndex === 0) {
    return formatGBT(c);
  }
  if (styleIndex === 1) {
    return formatAPA(c);
  }
  return formatMLA(c);
}

/** 生成带序号的参考文献列表文本 */
export function formatList(list: Citation[], styleIndex: number): string {
  const lines: string[] = [];
  for (let i = 0; i < list.length; i++) {
    lines.push('[' + (i + 1) + '] ' + formatCitation(list[i], styleIndex));
  }
  return lines.join('\n');
}

/** 生成检查结果文本 */
export function buildIssues(list: Citation[]): string[] {
  const issues: string[] = [];
  const dupIds: number[] = findDuplicateIds(list);
  for (let i = 0; i < list.length; i++) {
    const c: Citation = list[i];
    const miss: string[] = missingFields(c);
    if (miss.length > 0) {
      const names: string[] = [];
      for (let j = 0; j < miss.length; j++) {
        names.push(fieldLabel(miss[j]));
      }
      issues.push('【缺字段】《' + shortTitle(c.title) + '》：缺少 ' + names.join('、'));
    }
    let isDup = false;
    for (let j = 0; j < dupIds.length; j++) {
      if (dupIds[j] === c.id) {
        isDup = true;
        break;
      }
    }
    if (isDup) {
      issues.push('【疑似重复】《' + shortTitle(c.title) + '》：与其他条目标题或 DOI 相同，建议合并或删除');
    }
  }
  return issues;
}

function shortTitle(t: string): string {
  const s: string = t.trim();
  if (s.length <= 18) {
    return s;
  }
  return s.substring(0, 18) + '…';
}

/** 序列化（使用不可见分隔符，避免 JSON 类型转换问题） */
const SEP_FIELD: string = '\u001F';
const SEP_ENTRY: string = '\u001E';

export function serializeList(list: Citation[]): string {
  const parts: string[] = [];
  for (let i = 0; i < list.length; i++) {
    const c: Citation = list[i];
    parts.push(c.id.toString() + SEP_FIELD + c.type + SEP_FIELD + c.authors + SEP_FIELD + c.title +
      SEP_FIELD + c.year + SEP_FIELD + c.source + SEP_FIELD + c.city + SEP_FIELD + c.volume +
      SEP_FIELD + c.issue + SEP_FIELD + c.pages + SEP_FIELD + c.doi + SEP_FIELD + c.url);
  }
  return parts.join(SEP_ENTRY);
}

export function deserializeList(raw: string): Citation[] {
  const result: Citation[] = [];
  if (raw.length === 0) {
    return result;
  }
  const entries: string[] = raw.split(SEP_ENTRY);
  for (let i = 0; i < entries.length; i++) {
    const f: string[] = entries[i].split(SEP_FIELD);
    if (f.length >= 12) {
      const c: Citation = emptyCitation(Number(f[0]));
      c.type = f[1] as CitationType;
      c.authors = f[2];
      c.title = f[3];
      c.year = f[4];
      c.source = f[5];
      c.city = f[6];
      c.volume = f[7];
      c.issue = f[8];
      c.pages = f[9];
      c.doi = f[10];
      c.url = f[11];
      result.push(c);
    }
  }
  return result;
}

/** 示例数据：含 1 条缺字段条目、1 组重复条目，便于演示检查功能 */
export function sampleCitations(): Citation[] {
  const list: Citation[] = [];

  let c1: Citation = emptyCitation(1);
  c1.type = 'journal';
  c1.authors = '张伟, 李娜, 王强, 刘华';
  c1.title = '基于鸿蒙系统的校园应用开发框架研究';
  c1.year = '2025';
  c1.source = '计算机工程与应用';
  c1.volume = '61';
  c1.issue = '4';
  c1.pages = '112-120';
  c1.doi = '10.3778/j.issn.1002-8331.2025.04.012';
  list.push(c1);

  let c2: Citation = emptyCitation(2);
  c2.type = 'journal';
  c2.authors = '陈晨';
  c2.title = '移动学习环境下大学生课堂注意力研究';
  c2.year = '2024';
  c2.source = '';
  c2.volume = '';
  c2.issue = '3';
  c2.pages = '';
  list.push(c2);

  let c3: Citation = emptyCitation(3);
  c3.type = 'journal';
  c3.authors = '张伟, 李娜, 王强';
  c3.title = '基于鸿蒙系统的校园应用开发框架研究。';
  c3.year = '2025';
  c3.source = '计算机工程与应用';
  c3.volume = '61';
  c3.issue = '4';
  c3.pages = '112-120';
  c3.doi = '10.3778/j.issn.1002-8331.2025.04.012';
  list.push(c3);

  let c4: Citation = emptyCitation(4);
  c4.type = 'thesis';
  c4.authors = '刘洋';
  c4.title = '鸿蒙生态下跨端应用开发的关键技术研究';
  c4.year = '2024';
  c4.source = '北京邮电大学';
  c4.city = '北京';
  list.push(c4);

  let c5: Citation = emptyCitation(5);
  c5.type = 'conference';
  c5.authors = '赵敏, 孙浩';
  c5.title = '基于ArkTS的声明式UI性能优化方法';
  c5.year = '2025';
  c5.source = '2025年全国移动计算学术会议';
  c5.city = '成都';
  c5.pages = '45-52';
  list.push(c5);

  let c6: Citation = emptyCitation(6);
  c6.type = 'book';
  c6.authors = '李刚';
  c6.title = '鸿蒙应用开发实战';
  c6.year = '2024';
  c6.source = '人民邮电出版社';
  c6.city = '北京';
  list.push(c6);

  let c7: Citation = emptyCitation(7);
  c7.type = 'web';
  c7.authors = '华为开发者联盟';
  c7.title = 'HarmonyOS应用开发官方指南';
  c7.year = '2026';
  c7.url = 'https://developer.huawei.com/consumer/cn/harmonyos/';
  list.push(c7);

  let c8: Citation = emptyCitation(8);
  c8.type = 'journal';
  c8.authors = 'Anderson J. Miller, Smith K. Brown';
  c8.title = 'Declarative UI patterns in modern operating systems';
  c8.year = '2023';
  c8.source = 'Journal of Systems and Software';
  c8.volume = '210';
  c8.issue = '2';
  c8.pages = '111-122';
  c8.doi = '10.1016/j.jss.2023.111122';
  list.push(c8);

  return list;
}
