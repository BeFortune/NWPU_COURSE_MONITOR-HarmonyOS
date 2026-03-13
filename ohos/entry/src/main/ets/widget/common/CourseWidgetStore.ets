import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { formBindingData, formProvider } from '@kit.FormKit';

const LOG_DOMAIN = 0xFF20;
const LOG_TAG = 'CourseWidgetStore';
const DATA_FILE_NAME = 'course_widget_courses.json';
const FORM_IDS_FILE_NAME = 'course_widget_form_ids.json';

export interface WidgetCourseItem {
  courseName: string;
  timeRange: string;
  location: string;
  status: string;
}

export interface WidgetPayload {
  dateText: string;
  generatedAt: string;
  courses: Array<WidgetCourseItem>;
}

export function createDefaultPayload(): WidgetPayload {
  return {
    dateText: '今日课程',
    generatedAt: '--:--',
    courses: []
  };
}

export function toBindingObject(payload: WidgetPayload): Record<string, string> {
  return {
    dateText: payload.dateText,
    generatedAt: payload.generatedAt,
    coursesJson: JSON.stringify(payload.courses),
    courseCount: `${payload.courses.length}`,
    emptyText: payload.courses.length === 0 ? '今天没有课程，去享受片刻轻松。' : ''
  };
}

export async function loadWidgetPayload(context: common.Context): Promise<WidgetPayload> {
  try {
    const content = await readTextFile(`${context.filesDir}/${DATA_FILE_NAME}`);
    if (content.length === 0) {
      return createDefaultPayload();
    }
    return normalizePayload(JSON.parse(content) as WidgetPayload);
  } catch (error) {
    hilog.warn(LOG_DOMAIN, LOG_TAG, `loadWidgetPayload fallback: ${JSON.stringify(error)}`);
    return createDefaultPayload();
  }
}

export async function saveWidgetPayload(context: common.Context, payload: WidgetPayload): Promise<void> {
  const normalized = normalizePayload(payload);
  await writeTextFile(`${context.filesDir}/${DATA_FILE_NAME}`, JSON.stringify(normalized));
}

export async function addFormId(context: common.Context, formId: string): Promise<void> {
  const formIds = await loadFormIds(context);
  if (!formIds.includes(formId)) {
    formIds.push(formId);
    await writeTextFile(`${context.filesDir}/${FORM_IDS_FILE_NAME}`, JSON.stringify(formIds));
  }
}

export async function removeFormId(context: common.Context, formId: string): Promise<void> {
  const formIds = await loadFormIds(context);
  const next = formIds.filter(id => id !== formId);
  await writeTextFile(`${context.filesDir}/${FORM_IDS_FILE_NAME}`, JSON.stringify(next));
}

export async function loadFormIds(context: common.Context): Promise<Array<string>> {
  try {
    const content = await readTextFile(`${context.filesDir}/${FORM_IDS_FILE_NAME}`);
    if (content.length === 0) {
      return [];
    }
    const list = JSON.parse(content) as Array<string>;
    return Array.isArray(list) ? list : [];
  } catch (_) {
    return [];
  }
}

export async function refreshAllForms(context: common.Context, payload?: WidgetPayload): Promise<void> {
  const actualPayload = payload ?? await loadWidgetPayload(context);
  const data = formBindingData.createFormBindingData(toBindingObject(actualPayload));
  const formIds = await loadFormIds(context);

  for (let i = 0; i < formIds.length; i++) {
    const formId = formIds[i];
    try {
      await formProvider.updateForm(formId, data);
      hilog.info(LOG_DOMAIN, LOG_TAG, `updateForm success: ${formId}`);
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.error(
        LOG_DOMAIN,
        LOG_TAG,
        `updateForm failed: ${formId}, code=${businessError.code}, msg=${businessError.message}`
      );
    }
  }
}

function normalizePayload(payload: WidgetPayload): WidgetPayload {
  const courses = Array.isArray(payload.courses)
    ? payload.courses.map(item => ({
        courseName: item.courseName ?? '未命名课程',
        timeRange: item.timeRange ?? '--:--',
        location: item.location ?? '未设置',
        status: item.status ?? 'upcoming'
      }))
    : [];

  return {
    dateText: payload.dateText ?? '今日课程',
    generatedAt: payload.generatedAt ?? '--:--',
    courses
  };
}

async function readTextFile(path: string): Promise<string> {
  let file: fs.File | undefined = undefined;
  try {
    file = await fs.open(path, fs.OpenMode.READ_ONLY | fs.OpenMode.CREATE);
    const stat = await fs.stat(path);
    if (stat.size <= 0) {
      return '';
    }
    const buffer = new ArrayBuffer(stat.size);
    await fs.read(file.fd, buffer);
    return String.fromCharCode(...new Uint8Array(buffer));
  } finally {
    if (file) {
      await fs.close(file);
    }
  }
}

async function writeTextFile(path: string, content: string): Promise<void> {
  let file: fs.File | undefined = undefined;
  try {
    file = await fs.open(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    const encoded = new Uint8Array(Array.from(content).map(char => char.charCodeAt(0)));
    await fs.write(file.fd, encoded.buffer);
  } finally {
    if (file) {
      await fs.close(file);
    }
  }
}
