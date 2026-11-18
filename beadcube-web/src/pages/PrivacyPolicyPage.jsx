import React, { useState } from 'react';
import { Check, Copy } from 'lucide-react';
import { SITE_CONFIG } from '../siteConfig';

export default function PrivacyPolicyPage() {
  const [copied, setCopied] = useState(false);

  const copyPolicyUrl = async () => {
    try {
      await navigator.clipboard.writeText(SITE_CONFIG.privacyPolicyUrl);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      setCopied(false);
    }
  };

  return (
    <main className="policy-main">
      <div className="container">
        <article className="policy-article">
          <header className="policy-header">
            <h1>Privacy Policy</h1>
            <div className="policy-meta">
              <span>
                Effective {SITE_CONFIG.effectiveDate} · {SITE_CONFIG.appName} (
                <code>{SITE_CONFIG.packageId}</code>)
              </span>
              <button
                type="button"
                onClick={copyPolicyUrl}
                className="copy-btn"
                title="Copy Privacy Policy URL"
              >
                {copied ? <Check size={13} /> : <Copy size={13} />}
                {copied ? 'Copied' : 'Copy URL'}
              </button>
            </div>
          </header>

          <section className="policy-block">
            <h2>1. Overview</h2>
            <p>
              {SITE_CONFIG.appName} is a 3D spatial puzzle mobile game. You can
              play the game offline without creating an account or providing any
              personal information.
            </p>
          </section>

          <section className="policy-block">
            <h2>2. Information We Do Not Collect</h2>
            <p>
              We do not collect, store, or sell personally identifiable
              information, including your name, email address, phone number,
              precise location, contacts, photos, microphone, camera, or payment
              details.
            </p>
          </section>

          <section className="policy-block">
            <h2>3. Local On-Device Storage</h2>
            <p>
              Game progress — including unlocked levels, earned stars, Daily Cube
              streaks, daily hint counts, and audio/visual settings — is saved
              locally on your device using standard system preferences (
              <code>SharedPreferences</code> on Android and{' '}
              <code>NSUserDefaults</code> on iOS) and is never uploaded to our
              servers.
            </p>
          </section>

          <section className="policy-block">
            <h2>4. Optional Third-Party Services &amp; Ads</h2>
            <p>
              In versions of {SITE_CONFIG.appName} that include optional rewarded
              ads (such as Google AdMob for bonus hints or 3D previews), third-party
              ad providers may process standard device identifiers (AAID/IDFA),
              coarse IP-based region, and diagnostic signals to serve ads and
              prevent fraud. You can reset or limit ad tracking anytime in your
              device privacy settings. See{' '}
              <a
                href="https://policies.google.com/privacy"
                target="_blank"
                rel="noreferrer"
              >
                Google’s Privacy Policy
              </a>
              .
            </p>
          </section>

          <section className="policy-block">
            <h2>5. Children’s Privacy</h2>
            <p>
              {SITE_CONFIG.appName} is suitable for general audiences and does
              not knowingly collect personal information from children under 13.
            </p>
          </section>

          <section className="policy-block">
            <h2>6. Deleting Your Data</h2>
            <ul>
              <li>
                Tap <strong>Reset Progress</strong> inside the in-app Settings
                sheet to clear saved stars and streaks immediately.
              </li>
              <li>
                Uninstall {SITE_CONFIG.appName} or clear app storage in your
                device settings to remove all local data permanently.
              </li>
            </ul>
          </section>

          <section className="policy-block">
            <h2>7. Contact</h2>
            <p>
              Questions about this Privacy Policy can be sent to{' '}
              <a href={`mailto:${SITE_CONFIG.contactEmail}`}>
                {SITE_CONFIG.contactEmail}
              </a>
              .
            </p>
          </section>
        </article>
      </div>
    </main>
  );
}
