// UPI ID(VPA, Virtual Payment Address) 생성·검증 로직.
//
// 형식: <username>@<handle>
//   - username: PSP 앱/은행이 발급하는 사용자 식별부 (휴대폰번호, 이름 조합 등)
//   - handle  : PSP(결제서비스제공자) 핸들. 예) okaxis, ybl, paytm, ibl
//
// 주의: 이 모듈은 "형식(syntax)" 검증만 수행한다. 실제로 존재·활성 상태인지는
// NPCI/PSP의 VPA 조회(Verify VPA) API로만 확인할 수 있으며, 이 앱의 범위 밖이다.

/** username 허용 문자/길이 규칙 (NPCI 권고 및 주요 PSP 공통 규칙 기준) */
export const USERNAME_MIN = 3;
export const USERNAME_MAX = 50;
export const HANDLE_MIN = 2;
export const HANDLE_MAX = 64;
/** NPCI 기준 VPA 전체 최대 길이 */
export const VPA_MAX = 255;

export interface PspHandle {
  handle: string;
  provider: string;
}

/** 주요 PSP 핸들 목록 (화이트리스트가 아니라 "알려진 핸들" 참고용) */
export const KNOWN_HANDLES: PspHandle[] = [
  { handle: "okaxis", provider: "Google Pay (Axis Bank)" },
  { handle: "okhdfcbank", provider: "Google Pay (HDFC Bank)" },
  { handle: "okicici", provider: "Google Pay (ICICI Bank)" },
  { handle: "oksbi", provider: "Google Pay (SBI)" },
  { handle: "ybl", provider: "PhonePe (Yes Bank)" },
  { handle: "ibl", provider: "PhonePe (IndusInd Bank)" },
  { handle: "axl", provider: "PhonePe (Axis Bank)" },
  { handle: "paytm", provider: "Paytm" },
  { handle: "ptyes", provider: "Paytm (Yes Bank)" },
  { handle: "ptaxis", provider: "Paytm (Axis Bank)" },
  { handle: "pthdfc", provider: "Paytm (HDFC Bank)" },
  { handle: "ptsbi", provider: "Paytm (SBI)" },
  { handle: "apl", provider: "Amazon Pay (Axis Bank)" },
  { handle: "yapl", provider: "Amazon Pay (Yes Bank)" },
  { handle: "upi", provider: "BHIM" },
  { handle: "sbi", provider: "State Bank of India" },
  { handle: "icici", provider: "ICICI Bank" },
  { handle: "hdfcbank", provider: "HDFC Bank" },
  { handle: "axisbank", provider: "Axis Bank" },
  { handle: "kotak", provider: "Kotak Mahindra Bank" },
  { handle: "pnb", provider: "Punjab National Bank" },
  { handle: "barodampay", provider: "Bank of Baroda" },
  { handle: "freecharge", provider: "Freecharge" },
  { handle: "waaxis", provider: "WhatsApp Pay (Axis Bank)" },
  { handle: "wahdfcbank", provider: "WhatsApp Pay (HDFC Bank)" },
  { handle: "waicici", provider: "WhatsApp Pay (ICICI Bank)" },
  { handle: "wasbi", provider: "WhatsApp Pay (SBI)" },
];

const HANDLE_MAP = new Map(KNOWN_HANDLES.map((h) => [h.handle, h.provider]));

export function providerOf(handle: string): string | undefined {
  return HANDLE_MAP.get(handle.toLowerCase());
}

// ───────────────────────── 검증 ─────────────────────────

export type IssueCode =
  | "EMPTY"
  | "WHITESPACE"
  | "NO_AT"
  | "MULTIPLE_AT"
  | "USERNAME_EMPTY"
  | "USERNAME_LENGTH"
  | "USERNAME_CHARS"
  | "USERNAME_EDGE"
  | "USERNAME_CONSECUTIVE_DOTS"
  | "HANDLE_EMPTY"
  | "HANDLE_LENGTH"
  | "HANDLE_CHARS"
  | "HANDLE_START"
  | "TOO_LONG"
  | "UPPERCASE"
  | "UNKNOWN_HANDLE"
  | "INVALID_MOBILE";

export interface Issue {
  code: IssueCode;
  level: "error" | "warning";
  message: string;
}

export interface ValidationResult {
  input: string;
  /** 형식상 유효 여부 (error가 하나도 없으면 true) */
  valid: boolean;
  /** 소문자·trim 정규화 결과 (분리 가능할 때만) */
  normalized?: string;
  username?: string;
  handle?: string;
  provider?: string;
  /** username이 10자리 숫자(휴대폰번호 기반)인지 */
  mobileBased: boolean;
  issues: Issue[];
}

const USERNAME_CHARS = /^[a-z0-9._-]+$/;
const ALNUM = /[a-z0-9]/;
const HANDLE_CHARS = /^[a-z0-9]+$/;
/** 인도 휴대폰번호: 10자리, 6~9로 시작 */
const INDIAN_MOBILE = /^[6-9]\d{9}$/;

export function isIndianMobile(value: string): boolean {
  return INDIAN_MOBILE.test(value);
}

export function validateUpiId(raw: string): ValidationResult {
  const issues: Issue[] = [];
  const err = (code: IssueCode, message: string) =>
    issues.push({ code, level: "error", message });
  const warn = (code: IssueCode, message: string) =>
    issues.push({ code, level: "warning", message });

  const trimmed = raw.trim();
  const base: ValidationResult = {
    input: raw,
    valid: false,
    mobileBased: false,
    issues,
  };

  if (!trimmed) {
    err("EMPTY", "UPI ID가 비어 있습니다.");
    return base;
  }
  if (/\s/.test(trimmed)) {
    err("WHITESPACE", "UPI ID 중간에 공백을 포함할 수 없습니다.");
  }

  const atCount = (trimmed.match(/@/g) ?? []).length;
  if (atCount === 0) {
    err("NO_AT", "'@'가 없습니다. 형식: 사용자명@핸들 (예: 9876543210@ybl)");
    return base;
  }
  if (atCount > 1) {
    err("MULTIPLE_AT", "'@'는 정확히 1개여야 합니다.");
    return base;
  }

  if (trimmed !== trimmed.toLowerCase()) {
    warn("UPPERCASE", "대문자가 포함되어 있습니다. UPI ID는 소문자로 정규화되어 처리됩니다.");
  }

  const normalized = trimmed.toLowerCase();
  const [username, handle] = normalized.split("@");
  base.normalized = normalized;
  base.username = username;
  base.handle = handle;

  // username 규칙
  if (!username) {
    err("USERNAME_EMPTY", "'@' 앞 사용자명이 비어 있습니다.");
  } else {
    if (username.length < USERNAME_MIN || username.length > USERNAME_MAX) {
      err(
        "USERNAME_LENGTH",
        `사용자명은 ${USERNAME_MIN}~${USERNAME_MAX}자여야 합니다. (현재 ${username.length}자)`,
      );
    }
    if (!USERNAME_CHARS.test(username)) {
      err("USERNAME_CHARS", "사용자명에는 영문 소문자, 숫자, '.', '-', '_'만 사용할 수 있습니다.");
    } else {
      if (!ALNUM.test(username[0]) || !ALNUM.test(username[username.length - 1])) {
        err("USERNAME_EDGE", "사용자명은 영문 또는 숫자로 시작하고 끝나야 합니다.");
      }
      if (username.includes("..")) {
        err("USERNAME_CONSECUTIVE_DOTS", "사용자명에 '.'을 연속으로 쓸 수 없습니다.");
      }
    }
    if (/^\d+$/.test(username)) {
      if (username.length === 10) {
        base.mobileBased = true;
        if (!isIndianMobile(username)) {
          warn("INVALID_MOBILE", "10자리 숫자이지만 인도 휴대폰번호 형식(6~9로 시작)이 아닙니다.");
        }
      }
    }
  }

  // handle 규칙
  if (!handle) {
    err("HANDLE_EMPTY", "'@' 뒤 PSP 핸들이 비어 있습니다.");
  } else {
    if (handle.length < HANDLE_MIN || handle.length > HANDLE_MAX) {
      err("HANDLE_LENGTH", `핸들은 ${HANDLE_MIN}~${HANDLE_MAX}자여야 합니다. (현재 ${handle.length}자)`);
    }
    if (!HANDLE_CHARS.test(handle)) {
      err("HANDLE_CHARS", "핸들에는 영문 소문자와 숫자만 사용할 수 있습니다. (예: '.com' 같은 도메인 형식 불가)");
    } else if (!/^[a-z]/.test(handle)) {
      err("HANDLE_START", "핸들은 영문자로 시작해야 합니다.");
    }
    const provider = providerOf(handle);
    if (provider) base.provider = provider;
    else if (HANDLE_CHARS.test(handle)) {
      warn("UNKNOWN_HANDLE", `'@${handle}'은(는) 알려진 PSP 핸들 목록에 없습니다. 오타 여부를 확인하세요.`);
    }
  }

  if (normalized.length > VPA_MAX) {
    err("TOO_LONG", `UPI ID 전체 길이는 ${VPA_MAX}자를 넘을 수 없습니다.`);
  }

  base.valid = !issues.some((i) => i.level === "error");
  return base;
}

/** 여러 줄(개행/쉼표/세미콜론 구분) 입력을 일괄 검증 */
export function validateMany(text: string): ValidationResult[] {
  return text
    .split(/[\n,;]+/)
    .map((s) => s.trim())
    .filter(Boolean)
    .map(validateUpiId);
}

// ───────────────────────── 생성 ─────────────────────────

export type GenerateSource = "mobile" | "name" | "custom";

export interface GenerateInput {
  source: GenerateSource;
  /** source=mobile: 휴대폰번호 / name: 이름 / custom: 원하는 사용자명 */
  value: string;
  handle: string;
}

export interface GenerateOutput {
  candidates: string[];
  /** 입력 자체에 문제가 있을 때의 오류 메시지 */
  error?: string;
}

/** 이름/자유입력 문자열을 username 허용 문자로 정리 */
export function slugify(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "") // 악센트 제거
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, ".")
    .replace(/\.{2,}/g, ".")
    .replace(/^[._-]+|[._-]+$/g, "");
}

/** 휴대폰번호 입력에서 국가코드(+91/91/0)와 구분자를 제거 */
export function normalizeMobile(value: string): string {
  let digits = value.replace(/\D/g, "");
  if (digits.length === 12 && digits.startsWith("91")) digits = digits.slice(2);
  else if (digits.length === 11 && digits.startsWith("0")) digits = digits.slice(1);
  return digits;
}

function unique(list: string[]): string[] {
  return Array.from(new Set(list));
}

export function generateUpiIds(input: GenerateInput): GenerateOutput {
  const handle = input.handle.trim().toLowerCase().replace(/^@/, "");
  if (!handle) return { candidates: [], error: "PSP 핸들을 선택하거나 입력하세요." };
  if (!HANDLE_CHARS.test(handle) || !/^[a-z]/.test(handle)) {
    return { candidates: [], error: "핸들은 영문자로 시작하는 영문 소문자·숫자 조합이어야 합니다." };
  }

  let usernames: string[] = [];

  if (input.source === "mobile") {
    const mobile = normalizeMobile(input.value);
    if (!isIndianMobile(mobile)) {
      return {
        candidates: [],
        error: "인도 휴대폰번호 10자리(6~9로 시작)를 입력하세요. +91/0 접두어는 자동 제거됩니다.",
      };
    }
    usernames = [mobile];
  } else if (input.source === "name") {
    const parts = slugify(input.value).split(/[._-]+/).filter(Boolean);
    if (parts.length === 0) {
      return { candidates: [], error: "영문 이름을 입력하세요. (예: Rahul Sharma)" };
    }
    const first = parts[0];
    const last = parts.length > 1 ? parts[parts.length - 1] : "";
    usernames = last
      ? [
          `${first}.${last}`,
          `${first}${last}`,
          `${first}_${last}`,
          `${first[0]}${last}`,
          `${first}.${last[0]}`,
        ]
      : [first, `${first}.pay`, `${first}.upi`];
  } else {
    const slug = slugify(input.value);
    if (!slug) return { candidates: [], error: "사용자명을 입력하세요." };
    usernames = [slug];
  }

  const candidates = unique(usernames)
    .map((u) => `${u}@${handle}`)
    .filter((id) => validateUpiId(id).valid);

  if (candidates.length === 0) {
    return {
      candidates: [],
      error: `생성된 사용자명이 규칙(${USERNAME_MIN}~${USERNAME_MAX}자, 영숫자 시작·끝)을 만족하지 않습니다.`,
    };
  }
  return { candidates };
}

/** QA/테스트용 랜덤 UPI ID 생성 (휴대폰번호 기반 + 알려진 핸들) */
export function generateTestUpiIds(count: number, rand: () => number = Math.random): string[] {
  const n = Math.max(1, Math.min(100, Math.floor(count)));
  const out: string[] = [];
  for (let i = 0; i < n; i++) {
    let mobile = String(6 + Math.floor(rand() * 4));
    for (let d = 0; d < 9; d++) mobile += String(Math.floor(rand() * 10));
    const h = KNOWN_HANDLES[Math.floor(rand() * KNOWN_HANDLES.length)].handle;
    out.push(`${mobile}@${h}`);
  }
  return out;
}

// ───────────────────────── 결제 링크 ─────────────────────────

export interface PayLinkInput {
  vpa: string;
  payeeName?: string;
  /** 금액(INR). 빈 값이면 결제자가 입력 */
  amount?: string;
  note?: string;
}

/** NPCI UPI Linking Spec 기반 결제 딥링크 (upi://pay?...) */
export function buildPayLink(input: PayLinkInput): { link?: string; error?: string } {
  const v = validateUpiId(input.vpa);
  if (!v.valid || !v.normalized) return { error: "유효한 UPI ID를 먼저 입력하세요." };

  const params = new URLSearchParams({ pa: v.normalized });
  if (input.payeeName?.trim()) params.set("pn", input.payeeName.trim());
  if (input.amount?.trim()) {
    const amount = input.amount.trim();
    if (!/^\d+(\.\d{1,2})?$/.test(amount) || Number(amount) <= 0) {
      return { error: "금액은 0보다 큰 숫자(소수점 2자리까지)여야 합니다." };
    }
    params.set("am", Number(amount).toFixed(2));
  }
  params.set("cu", "INR");
  if (input.note?.trim()) params.set("tn", input.note.trim());
  // URLSearchParams는 공백을 '+'로 인코딩하므로 UPI 앱 호환을 위해 %20으로 치환
  return { link: `upi://pay?${params.toString().replace(/\+/g, "%20")}` };
}
