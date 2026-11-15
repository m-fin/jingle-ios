import assert from "node:assert/strict";
import { test } from "node:test";

import { BUNDLE_ID, privacyPolicyUrl } from "./release";

test("keeps the v1 bundle id explicit", () => {
  assert.equal(BUNDLE_ID, "app.jingle.ios");
});

test("accepts only https privacy policy urls", () => {
  assert.equal(privacyPolicyUrl(undefined), null);
  assert.equal(privacyPolicyUrl(null), null);
  assert.equal(privacyPolicyUrl("   "), null);
  assert.equal(privacyPolicyUrl("http://example.com/privacy"), null);
  assert.equal(privacyPolicyUrl("javascript:alert(1)"), null);
  assert.equal(privacyPolicyUrl("not a url"), null);
  assert.equal(
    privacyPolicyUrl(" https://github.com/m-fin/jingle-ios/blob/main/PRIVACY.md "),
    "https://github.com/m-fin/jingle-ios/blob/main/PRIVACY.md",
  );
});
