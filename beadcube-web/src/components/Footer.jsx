import React from 'react';
import { Link } from 'react-router-dom';
import { SITE_CONFIG } from '../siteConfig';

export default function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer className="footer">
      <div className="container footer-inner">
        <span>
          © {year} {SITE_CONFIG.appName}
        </span>
        <div className="footer-links">
          <Link to={SITE_CONFIG.privacyPath}>Privacy Policy</Link>
          <a href={`mailto:${SITE_CONFIG.contactEmail}`}>
            {SITE_CONFIG.contactEmail}
          </a>
        </div>
      </div>
    </footer>
  );
}
