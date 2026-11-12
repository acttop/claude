"use client";

import { useMemo, useState } from "react";
import {
  buildPayLink,
  generateTestUpiIds,
  generateUpiIds,
  KNOWN_HANDLES,
  validateMany,
  validateUpiId,
  type GenerateSource,
  type ValidationResult,
} from "@/lib/upi";

type Tab = "validate" | "generate" | "paylink";

const TABS: { id: Tab; label: string }[] = [
  { id: "validate", label: "검증" },
  { id: "generate", label: "생성" },
  { id: "paylink", label: "결제 링크" },
];

const SCOPE_NOTICE =
  "이 화면은 UPI ID의 형식(syntax)만 검증합니다. 실제 존재·활성 여부와 예금주명은 NPCI/PSP의 VPA 조회 API로만 확인할 수 있습니다.";

async function copy(text: string) {
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    /* 클립보드 권한이 없으면 무시 */
  }
}

function StatusBadge({ r }: { r: ValidationResult }) {
  const warnings = r.issues.filter((i) => i.level === "warning").length;
  if (!r.valid) return <span className="badge badge-error">오류</span>;
  if (warnings) return <span className="badge badge-warn">유효(경고)</span>;
  return <span className="badge badge-ok">유효</span>;
}

function IssueList({ r }: { r: ValidationResult }) {
  if (r.issues.length === 0) return <span className="muted">-</span>;
  return (
    <ul className="issue-list">
      {r.issues.map((i) => (
        <li key={i.code} className={i.level}>
          {i.level === "error" ? "✕" : "!"} {i.message}
        </li>
      ))}
    </ul>
  );
}

// ───────────── 검증 탭 ─────────────
function ValidatePanel() {
  const [single, setSingle] = useState("");
  const [bulk, setBulk] = useState("");
  const singleResult = useMemo(() => (single.trim() ? validateUpiId(single) : null), [single]);
  const bulkResults = useMemo(() => validateMany(bulk), [bulk]);
  const validCount = bulkResults.filter((r) => r.valid).length;

  return (
    <>
      <section className="card">
        <h2>단건 검증</h2>
        <div className="field">
          <label htmlFor="upi-single">UPI ID</label>
          <input
            id="upi-single"
            value={single}
            onChange={(e) => setSingle(e.target.value)}
            placeholder="예: 9876543210@ybl"
            autoComplete="off"
            spellCheck={false}
          />
        </div>
        {singleResult && (
          <div className="result-box">
            <div className="result-head">
              <StatusBadge r={singleResult} />
              {singleResult.normalized && <code>{singleResult.normalized}</code>}
            </div>
            {singleResult.username !== undefined && (
              <dl className="kv">
                <dt>사용자명</dt>
                <dd>
                  {singleResult.username || "-"}
                  {singleResult.mobileBased && <span className="badge">휴대폰번호 기반</span>}
                </dd>
                <dt>PSP 핸들</dt>
                <dd>@{singleResult.handle || "-"}</dd>
                <dt>제공사</dt>
                <dd>{singleResult.provider ?? "알 수 없음"}</dd>
              </dl>
            )}
            <IssueList r={singleResult} />
          </div>
        )}
      </section>

      <section className="card">
        <h2>일괄 검증</h2>
        <div className="field">
          <label htmlFor="upi-bulk">UPI ID 목록 (줄바꿈·쉼표·세미콜론 구분)</label>
          <textarea
            id="upi-bulk"
            rows={6}
            value={bulk}
            onChange={(e) => setBulk(e.target.value)}
            placeholder={"9876543210@ybl\nrahul.sharma@okaxis\nwrong@gmail.com"}
            spellCheck={false}
          />
        </div>
        <div className="form-actions">
          <button type="button" onClick={() => setBulk(generateTestUpiIds(10).join("\n") + "\nwrong@gmail.com\nab@ybl")}>
            샘플 데이터 채우기
          </button>
          <button type="button" onClick={() => setBulk("")} disabled={!bulk}>
            초기화
          </button>
        </div>
        {bulkResults.length > 0 && (
          <>
            <p className="summary">
              총 <strong>{bulkResults.length}</strong>건 · 유효 <strong>{validCount}</strong>건 · 오류{" "}
              <strong>{bulkResults.length - validCount}</strong>건
            </p>
            <div className="table-wrap">
              <table className="results upi-table">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>입력값</th>
                    <th>결과</th>
                    <th>제공사</th>
                    <th>상세</th>
                  </tr>
                </thead>
                <tbody>
                  {bulkResults.map((r, idx) => (
                    <tr key={idx}>
                      <td>{idx + 1}</td>
                      <td>
                        <code>{r.input}</code>
                      </td>
                      <td>
                        <StatusBadge r={r} />
                      </td>
                      <td>{r.provider ?? "-"}</td>
                      <td className="wrap">
                        <IssueList r={r} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </section>
    </>
  );
}

// ───────────── 생성 탭 ─────────────
const SOURCE_META: Record<GenerateSource, { label: string; placeholder: string }> = {
  mobile: { label: "휴대폰번호", placeholder: "+91 98765 43210" },
  name: { label: "영문 이름", placeholder: "Rahul Sharma" },
  custom: { label: "사용자 지정", placeholder: "myshop01" },
};

function GeneratePanel() {
  const [source, setSource] = useState<GenerateSource>("mobile");
  const [value, setValue] = useState("");
  const [handle, setHandle] = useState("ybl");
  const [testCount, setTestCount] = useState("10");
  const [testIds, setTestIds] = useState<string[]>([]);

  const result = useMemo(
    () => (value.trim() ? generateUpiIds({ source, value, handle }) : null),
    [source, value, handle],
  );

  return (
    <>
      <section className="card">
        <h2>UPI ID 생성</h2>
        <div className="grid">
          <div className="field">
            <label htmlFor="gen-source">생성 기준</label>
            <select id="gen-source" value={source} onChange={(e) => setSource(e.target.value as GenerateSource)}>
              {(Object.keys(SOURCE_META) as GenerateSource[]).map((s) => (
                <option key={s} value={s}>
                  {SOURCE_META[s].label}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label htmlFor="gen-value">{SOURCE_META[source].label}</label>
            <input
              id="gen-value"
              value={value}
              onChange={(e) => setValue(e.target.value)}
              placeholder={SOURCE_META[source].placeholder}
              autoComplete="off"
            />
          </div>
          <div className="field">
            <label htmlFor="gen-handle">PSP 핸들</label>
            <input
              id="gen-handle"
              list="handle-list"
              value={handle}
              onChange={(e) => setHandle(e.target.value)}
              placeholder="ybl"
            />
            <datalist id="handle-list">
              {KNOWN_HANDLES.map((h) => (
                <option key={h.handle} value={h.handle}>
                  {h.provider}
                </option>
              ))}
            </datalist>
          </div>
        </div>

        {result?.error && <div className="inline-error">{result.error}</div>}
        {result && result.candidates.length > 0 && (
          <ul className="candidate-list">
            {result.candidates.map((id) => (
              <li key={id}>
                <code>{id}</code>
                <button type="button" onClick={() => copy(id)}>
                  복사
                </button>
              </li>
            ))}
          </ul>
        )}
        <p className="hint">
          생성된 ID는 형식상 유효한 <strong>후보</strong>이며, 실제 발급은 해당 PSP 앱에서 이루어집니다.
        </p>
      </section>

      <section className="card">
        <h2>QA용 테스트 데이터</h2>
        <div className="form-actions">
          <input
            className="count-input"
            type="number"
            min={1}
            max={100}
            value={testCount}
            onChange={(e) => setTestCount(e.target.value)}
            aria-label="생성 개수"
          />
          <button type="button" className="primary" onClick={() => setTestIds(generateTestUpiIds(Number(testCount) || 10))}>
            랜덤 생성
          </button>
          <button type="button" disabled={!testIds.length} onClick={() => copy(testIds.join("\n"))}>
            전체 복사
          </button>
        </div>
        {testIds.length > 0 && <pre className="test-output">{testIds.join("\n")}</pre>}
      </section>
    </>
  );
}

// ───────────── 결제 링크 탭 ─────────────
function PayLinkPanel() {
  const [vpa, setVpa] = useState("");
  const [payeeName, setPayeeName] = useState("");
  const [amount, setAmount] = useState("");
  const [note, setNote] = useState("");
  const result = useMemo(
    () => (vpa.trim() ? buildPayLink({ vpa, payeeName, amount, note }) : null),
    [vpa, payeeName, amount, note],
  );

  return (
    <section className="card">
      <h2>UPI 결제 딥링크</h2>
      <div className="grid">
        <div className="field">
          <label htmlFor="pl-vpa">수취인 UPI ID *</label>
          <input id="pl-vpa" value={vpa} onChange={(e) => setVpa(e.target.value)} placeholder="shop@ybl" />
        </div>
        <div className="field">
          <label htmlFor="pl-name">수취인 이름</label>
          <input id="pl-name" value={payeeName} onChange={(e) => setPayeeName(e.target.value)} placeholder="My Shop" />
        </div>
        <div className="field">
          <label htmlFor="pl-amount">금액 (INR)</label>
          <input
            id="pl-amount"
            inputMode="decimal"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="비우면 결제자가 입력"
          />
        </div>
        <div className="field">
          <label htmlFor="pl-note">메모</label>
          <input id="pl-note" value={note} onChange={(e) => setNote(e.target.value)} placeholder="Order 12" />
        </div>
      </div>
      {result?.error && <div className="inline-error">{result.error}</div>}
      {result?.link && (
        <div className="result-box">
          <code className="link">{result.link}</code>
          <div className="form-actions">
            <button type="button" onClick={() => copy(result.link!)}>
              링크 복사
            </button>
          </div>
        </div>
      )}
      <p className="hint">NPCI UPI Linking Specification의 upi://pay 형식입니다. 모바일 UPI 앱에서 열면 결제 화면으로 연결됩니다.</p>
    </section>
  );
}

export default function UpiScreen() {
  const [tab, setTab] = useState<Tab>("validate");

  return (
    <main className="container">
      <header className="page-header">
        <h1>UPI ID 생성·검증</h1>
        <p>인도 UPI(Unified Payments Interface) 결제 주소(VPA)의 형식 검증, 후보 생성, 결제 링크 생성 도구입니다.</p>
        <nav className="source-links" aria-label="관련 링크">
          <a href="https://www.npci.org.in/what-we-do/upi/product-overview" target="_blank" rel="noreferrer">
            NPCI UPI 개요
          </a>
        </nav>
      </header>

      <div className="notice">{SCOPE_NOTICE}</div>

      <div className="tabs" role="tablist">
        {TABS.map((t) => (
          <button
            key={t.id}
            role="tab"
            aria-selected={tab === t.id}
            className={tab === t.id ? "tab active" : "tab"}
            onClick={() => setTab(t.id)}
          >
            {t.label}
          </button>
        ))}
      </div>

      {tab === "validate" && <ValidatePanel />}
      {tab === "generate" && <GeneratePanel />}
      {tab === "paylink" && <PayLinkPanel />}
    </main>
  );
}
