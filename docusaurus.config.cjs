// @ts-check

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Forms development',
  tagline: 'Development tools and documentation for the Defra Forms application suite',

  url: 'https://defra.github.io',
  baseUrl: '/forms-development-tools/',

  organizationName: 'defra',
  projectName: 'forms-development-tools',
  deploymentBranch: 'main',
  trailingSlash: false,

  onBrokenLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [],

  themes: [
    [
      require.resolve('@easyops-cn/docusaurus-search-local'),
      /** @type {import("@easyops-cn/docusaurus-search-local").PluginOptions} */
      ({
        docsRouteBasePath: '/',
        indexBlog: false,
        indexPages: false,
        hashed: 'filename',
        highlightSearchTermsOnTargetPage: true,
        searchResultContextMaxLength: 60,
      }),
    ],
    '@defra/docusaurus-theme-govuk',
  ],

  plugins: [
    [
      '@docusaurus/plugin-content-docs',
      {
        routeBasePath: '/',
        exclude: ['superpowers/**'],
        editUrl: 'https://github.com/DEFRA/forms-development-tools/tree/main/',
      },
    ],
  ],

  themeConfig: {
    // Required by @docusaurus/plugin-content-docs when not using preset-classic;
    // the easyops SearchBarWrapper reads useThemeConfig().docs during SSR.
    docs: {
      versionPersistence: 'localStorage',
    },
    govuk: {
      header: {
        serviceName: 'Forms development',
        serviceHref: '/',
        organisationText: 'Defra DDTS',
        organisationHref: 'https://github.com/defra',
      },
      navigation: [
        {
          text: 'Architecture diagrams',
          href: '/architecture-diagrams',
        },
      ],
      footer: {
        meta: [
          { text: 'GitHub', href: 'https://github.com/DEFRA/forms-development-tools' },
        ],
      },
      homepage: {
        getStartedHref: '/architecture-diagrams',
        description: 'Documentation and tooling for developers working on the Defra Forms application suite.',
      },
    },
  },
};

module.exports = config;
