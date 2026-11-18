import React, { useEffect } from 'react';
import { BrowserRouter, Navigate, Route, Routes, useLocation } from 'react-router-dom';
import Navbar from './components/Navbar';
import Footer from './components/Footer';
import LandingPage from './pages/LandingPage';
import PrivacyPolicyPage from './pages/PrivacyPolicyPage';
import { SITE_CONFIG } from './siteConfig';

function RouteMetadataUpdater() {
  const { pathname } = useLocation();

  useEffect(() => {
    window.scrollTo(0, 0);
    document.title = pathname.startsWith('/privacy')
      ? `Privacy Policy — ${SITE_CONFIG.appName}`
      : `${SITE_CONFIG.appName} — 3D Spatial Puzzle`;
  }, [pathname]);

  return null;
}

export default function App() {
  return (
    <BrowserRouter>
      <RouteMetadataUpdater />
      <div className="page-shell">
        <Navbar />
        <Routes>
          <Route path="/" element={<LandingPage />} />
          <Route path="/privacy-policy" element={<PrivacyPolicyPage />} />
          <Route
            path="/privacy"
            element={<Navigate to="/privacy-policy" replace />}
          />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
        <Footer />
      </div>
    </BrowserRouter>
  );
}
