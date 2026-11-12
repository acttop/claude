// 실행: npm test  (Node 22 타입 스트리핑 + node:test)
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  buildPayLink,
  generateTestUpiIds,
  generateUpiIds,
  normalizeMobile,
  validateMany,
  validateUpiId,
} from "./upi.ts";

const codes = (id: string) => validateUpiId(id).issues.map((i) => i.code);

test("정상 UPI ID", () => {
  const r = validateUpiId("9876543210@ybl");
  assert.equal(r.valid, true);
  assert.equal(r.provider, "PhonePe (Yes Bank)");
  assert.equal(r.mobileBased, true);
  assert.deepEqual(r.issues, []);

  assert.equal(validateUpiId("rahul.sharma@okaxis").valid, true);
  assert.equal(validateUpiId("a-b_c.d@paytm").valid, true);
});

test("대문자는 경고 후 소문자로 정규화", () => {
  const r = validateUpiId("  Rahul.Sharma@OKAXIS ");
  assert.equal(r.valid, true);
  assert.equal(r.normalized, "rahul.sharma@okaxis");
  assert.deepEqual(codes("Rahul@okaxis"), ["UPPERCASE"]);
});

test("형식 오류", () => {
  assert.deepEqual(codes(""), ["EMPTY"]);
  assert.deepEqual(codes("rahulokaxis"), ["NO_AT"]);
  assert.deepEqual(codes("a@b@c"), ["MULTIPLE_AT"]);
  assert.ok(codes("@ybl").includes("USERNAME_EMPTY"));
  assert.ok(codes("rahul@").includes("HANDLE_EMPTY"));
  assert.ok(codes("ab@ybl").includes("USERNAME_LENGTH"));
  assert.ok(codes("rahul#1@ybl").includes("USERNAME_CHARS"));
  assert.ok(codes(".rahul@ybl").includes("USERNAME_EDGE"));
  assert.ok(codes("rahul..s@ybl").includes("USERNAME_CONSECUTIVE_DOTS"));
  assert.ok(codes("rahul@gmail.com").includes("HANDLE_CHARS"));
  assert.ok(codes("rahul@1bank").includes("HANDLE_START"));
  assert.ok(codes("rahul s@ybl").includes("WHITESPACE"));
  assert.equal(validateUpiId("rahul@gmail.com").valid, false);
});

test("경고만 있으면 valid=true", () => {
  const r = validateUpiId("rahul@mybank");
  assert.equal(r.valid, true);
  assert.deepEqual(codes("rahul@mybank"), ["UNKNOWN_HANDLE"]);
  assert.deepEqual(codes("1234567890@ybl"), ["INVALID_MOBILE"]);
});

test("일괄 검증: 개행/쉼표/세미콜론 구분", () => {
  const rs = validateMany("9876543210@ybl\nbad, rahul@okaxis; ");
  assert.deepEqual(
    rs.map((r) => [r.input, r.valid]),
    [
      ["9876543210@ybl", true],
      ["bad", false],
      ["rahul@okaxis", true],
    ],
  );
});

test("휴대폰번호 정규화", () => {
  assert.equal(normalizeMobile("+91 98765-43210"), "9876543210");
  assert.equal(normalizeMobile("09876543210"), "9876543210");
});

test("생성: 휴대폰번호 기반", () => {
  assert.deepEqual(generateUpiIds({ source: "mobile", value: "+91 98765 43210", handle: "@YBL" }), {
    candidates: ["9876543210@ybl"],
  });
  assert.ok(generateUpiIds({ source: "mobile", value: "12345", handle: "ybl" }).error);
});

test("생성: 이름 기반 후보", () => {
  const r = generateUpiIds({ source: "name", value: "Rahul Kumar Sharma", handle: "okaxis" });
  assert.deepEqual(r.candidates, [
    "rahul.sharma@okaxis",
    "rahulsharma@okaxis",
    "rahul_sharma@okaxis",
    "rsharma@okaxis",
    "rahul.s@okaxis",
  ]);
  assert.deepEqual(generateUpiIds({ source: "name", value: "Priya", handle: "paytm" }).candidates, [
    "priya@paytm",
    "priya.pay@paytm",
    "priya.upi@paytm",
  ]);
  assert.ok(generateUpiIds({ source: "name", value: "홍길동", handle: "ybl" }).error);
});

test("생성: 사용자 지정 / 잘못된 핸들", () => {
  assert.deepEqual(generateUpiIds({ source: "custom", value: "My Shop 01", handle: "ibl" }).candidates, [
    "my.shop.01@ibl",
  ]);
  assert.ok(generateUpiIds({ source: "custom", value: "shop", handle: "gmail.com" }).error);
});

test("테스트 데이터 생성은 모두 유효", () => {
  const ids = generateTestUpiIds(50);
  assert.equal(ids.length, 50);
  for (const id of ids) assert.equal(validateUpiId(id).valid, true, id);
  assert.deepEqual(codes(ids[0]).filter((c) => c !== "UNKNOWN_HANDLE"), []);
});

test("결제 딥링크", () => {
  assert.deepEqual(
    buildPayLink({ vpa: "Shop@YBL", payeeName: "My Shop", amount: "150.5", note: "Order 12" }),
    { link: "upi://pay?pa=shop%40ybl&pn=My%20Shop&am=150.50&cu=INR&tn=Order%2012" },
  );
  assert.ok(buildPayLink({ vpa: "bad" }).error);
  assert.ok(buildPayLink({ vpa: "shop@ybl", amount: "-1" }).error);
});
