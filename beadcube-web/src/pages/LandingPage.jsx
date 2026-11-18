import React from 'react';
import { Link } from 'react-router-dom';
import InteractiveCubeShowcase from '../components/InteractiveCubeShowcase';
import { SITE_CONFIG } from '../siteConfig';

export default function LandingPage() {
  return (
    <main>
      <section className="hero">
        <div className="container">
          <InteractiveCubeShowcase />

          <h1 className="hero-title">{SITE_CONFIG.appName}</h1>
          <p className="hero-lead">
            A calm 3D spatial puzzle. Fold colorful bead blocks seamlessly across
            cube edges through 100 handcrafted levels.
          </p>

          <div className="hero-actions">
            <a href="#about" className="btn-primary">
              Google Play · Coming Soon
            </a>
            <Link to={SITE_CONFIG.privacyPath} className="btn-ghost">
              Privacy Policy
            </Link>
          </div>
        </div>
      </section>

      <section id="about" className="pillars">
        <div className="container pillars-grid">
          <div className="pillar">
            <h3>90° Edge Folding</h3>
            <p>
              Flat polyomino pieces bend naturally over cube seams to match the
              unfolded 6-face target plan.
            </p>
          </div>

          <div className="pillar">
            <h3>100 Levels &amp; Daily Cube</h3>
            <p>
              Progress at your own pace from single-face warmups to full 6-face
              cubes, plus a fresh Daily Cube each day.
            </p>
          </div>

          <div className="pillar">
            <h3>Offline &amp; Private</h3>
            <p>
              Zero timers, zero sign-ups, and zero personal data collection.
              Your progress stays right on your device.
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
