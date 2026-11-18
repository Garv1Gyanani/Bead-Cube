import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { SITE_CONFIG } from '../siteConfig';

export default function Navbar() {
  const { pathname } = useLocation();
  const isPrivacy = pathname.startsWith('/privacy');

  return (
    <header className="header">
      <div className="container header-inner">
        <Link to="/" className="brand">
          <img
            src="/logo.png"
            alt={SITE_CONFIG.appName}
            className="brand-logo"
          />
          <span className="brand-name">{SITE_CONFIG.appName}</span>
        </Link>

        <nav className="nav-links" aria-label="Navigation">
          <Link to="/" className={!isPrivacy ? 'active' : ''}>
            Overview
          </Link>
          <Link to={SITE_CONFIG.privacyPath} className={isPrivacy ? 'active' : ''}>
            Privacy
          </Link>
        </nav>
      </div>
    </header>
  );
}
