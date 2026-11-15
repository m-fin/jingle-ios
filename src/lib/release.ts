/** App Store bundle id. Keep this in sync with app.json. */
export const BUNDLE_ID = "app.jingle.ios";

/** Marketing version shipped as v1. Keep this in sync with app.json. */
export const APP_VERSION = "1.0.0";

export const SOURCE_REPOSITORY = "https://github.com/m-fin/jingle-ios";

/**
 * Accept a public privacy-policy URL from configuration.
 * Empty values and anything that is not https are ignored so a placeholder cannot ship as a link.
 */
export function privacyPolicyUrl(raw: string | undefined | null): string | null {
  const value = raw?.trim();
  if (!value) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== "https:") return null;
    if (!url.hostname) return null;
    return url.toString();
  } catch {
    return null;
  }
}
