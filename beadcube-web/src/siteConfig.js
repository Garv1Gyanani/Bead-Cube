export const SITE_CONFIG = {
  appName: 'Bead Cube',
  tagline: 'Fold · Match · Relax',
  netlifyUsername: 'beadcube',
  siteUrl: 'https://beadcube.netlify.app',
  privacyPath: '/privacy-policy',
  get privacyPolicyUrl() {
    return `${this.siteUrl}${this.privacyPath}`;
  },
  packageId: 'com.beadcube.game',
  contactEmail: 'support@beadcube.app',
  effectiveDate: 'November 18, 2026',
};
