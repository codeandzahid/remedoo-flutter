// Parser tests for Remedoo Pay (node test-parse.mjs)
//
// The bank-credit parser lives inside worker.js (the Worker is one
// self-contained file for dashboard paste-deploy, so nothing is
// exported). This script extracts the parser + Gmail body helpers
// from worker.js and runs realistic bank alert EMAIL bodies through
// them — the same fixtures the SMS observer would see as SMS text,
// plus Gmail message shapes (base64url parts, HTML-only mail).
//
// Run: node remedoo-pay/test-parse.mjs   (exit 1 on any failure)

import { readFileSync } from 'node:fs';

const src = readFileSync(new URL('./worker.js', import.meta.url), 'utf8');

function extract(name) {
  const start = src.indexOf(`function ${name}(`);
  if (start < 0) throw new Error(`function ${name} not found in worker.js`);
  const end = src.indexOf('\n}', start);
  if (end < 0) throw new Error(`function ${name} has no closing brace`);
  return src.slice(start, end + 2);
}

const { parseBankSms, gmailMessageText, sanitizeEmailPayer } = new Function(
  [
    extract('parseBankSms'),
    extract('decodeB64Url'),
    extract('findMimePart'),
    extract('stripHtml'),
    extract('gmailMessageText'),
    extract('sanitizeEmailPayer'),
    'return { parseBankSms, gmailMessageText, sanitizeEmailPayer };',
  ].join('\n')
)();

let failures = 0;
function check(label, actual, expected) {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a === e) {
    console.log(`ok   ${label}`);
  } else {
    failures += 1;
    console.log(`FAIL ${label}\n     expected ${e}\n     actual   ${a}`);
  }
}

// ------------------------------------------------------------------
// Fixture 1 — HDFC-style credit alert email (plain text)
// ------------------------------------------------------------------
const hdfcEmail = [
  'Dear Customer,',
  '',
  'Greetings from HDFC Bank!',
  '',
  'Your account XXXX4321 has been credited with Rs. 1,500.00 on 19-OCT-2026.',
  'Transaction details: UPI/CR/529281736455/RAHUL SHARMA/rahul.sharma@okicici',
  'UPI Ref No: 529281736455',
  '',
  'Available balance: Rs. 12,340.50',
].join('\n');

const hdfc = parseBankSms(hdfcEmail);
check('hdfc: amount', hdfc?.paise, 150000);
check('hdfc: utr', hdfc?.utr, '529281736455');
check('hdfc: payer vpa', hdfc?.payerVpa, 'rahul.sharma@okicici');

// ------------------------------------------------------------------
// Fixture 2 — ICICI-style credit alert email (payer name via "from")
// ------------------------------------------------------------------
const iciciEmail =
  'Dear Customer, your account XX9876 has been credited with ' +
  'Rs. 750.50 on 19-Oct-2026. Amount received from ZAHID MANZOOR ' +
  'via UPI (zahid.m@okaxis). UPI Ref: 632145987012. ' +
  'Thank you for banking with us.';

const icici = parseBankSms(iciciEmail);
check('icici: amount', icici?.paise, 75050);
check('icici: utr', icici?.utr, '632145987012');
check('icici: payer vpa', icici?.payerVpa, 'zahid.m@okaxis');
check('icici: payer name', icici?.payerName, 'ZAHID MANZOOR');

// ------------------------------------------------------------------
// Fixture 3 — YBL-style alert as an HTML-only Gmail message
// (exercises gmailMessageText -> stripHtml -> parser end to end)
// ------------------------------------------------------------------
const yblHtml =
  '<html><body>' +
  '<p>Your YBL account has been <b>credited</b> with Rs.500.00.</p>' +
  '<p>Received from customer@paytm.</p>' +
  '<p>Txn ID: 529811223344</p>' +
  '<p>Balance: Rs. 8,215.00</p>' +
  '</body></html>';

const b64url = (s) =>
  Buffer.from(s, 'utf8')
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

const yblMsg = {
  snippet: 'Your YBL account has been credited with Rs.500.00.',
  payload: {
    mimeType: 'multipart/alternative',
    parts: [
      { mimeType: 'text/html', body: { data: b64url(yblHtml) } },
    ],
  },
};
const ybl = parseBankSms(gmailMessageText(yblMsg));
check('ybl html: amount', ybl?.paise, 50000);
check('ybl html: utr', ybl?.utr, '529811223344');
check('ybl html: payer vpa', ybl?.payerVpa, 'customer@paytm');

// ------------------------------------------------------------------
// Fixture 4 — multipart Gmail message: text/plain wins over html
// ------------------------------------------------------------------
const multiMsg = {
  snippet: 'credited',
  payload: {
    mimeType: 'multipart/alternative',
    parts: [
      { mimeType: 'text/plain', body: { data: b64url(hdfcEmail) } },
      { mimeType: 'text/html', body: { data: b64url('<p>html copy</p>') } },
    ],
  },
};
const multi = parseBankSms(gmailMessageText(multiMsg));
check('multipart: amount', multi?.paise, 150000);
check('multipart: utr', multi?.utr, '529281736455');

// ------------------------------------------------------------------
// Fixture 5 — a DEBIT alert must never confirm a payment
// ------------------------------------------------------------------
const debitEmail =
  'Dear Customer, your account XX9876 has been debited with ' +
  'Rs. 250.00 on 19-Oct-2026 for a UPI payment. UPI Ref: 632145987099.';
check('debit email: rejected', parseBankSms(debitEmail), null);

// ------------------------------------------------------------------
// sanitizeEmailPayer: an email address is not a UPI handle
// ------------------------------------------------------------------
check(
  'sanitize: email-like payer dropped',
  sanitizeEmailPayer({ paise: 100, utr: null, payerVpa: 'care@hdfcbank.com', payerName: null })?.payerVpa,
  null
);
check(
  'sanitize: real UPI handle kept',
  sanitizeEmailPayer({ paise: 100, utr: null, payerVpa: 'rahul@okicici', payerName: null })?.payerVpa,
  'rahul@okicici'
);

if (failures > 0) {
  console.log(`\n${failures} check(s) FAILED`);
  process.exit(1);
}
console.log('\nAll parser checks passed.');
