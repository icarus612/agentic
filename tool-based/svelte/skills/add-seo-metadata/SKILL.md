---
name: add-seo-metadata
description: Use when adding SEO to a SvelteKit page — <svelte:head> title/description, Open Graph and Twitter cards, canonical URLs, JSON-LD structured data, and a Core Web Vitals checklist.
domain: svelte
rules: [accessibility]
model: sonnet
model-fallback: [gemini-pro]
---

# add-seo-metadata

Add per-page metadata with `<svelte:head>`. Every route gets a unique title and description; content-type pages add structured data.

## Meta, Open Graph, Twitter, canonical

Derive values from the page's loaded data rather than hardcoding.

```svelte
<script lang="ts">
  let { data } = $props();
  const { title, description, image, url } = data.meta;
</script>

<svelte:head>
  <title>{title}</title>
  <meta name="description" content={description} />

  <!-- Open Graph -->
  <meta property="og:type" content="website" />
  <meta property="og:title" content={title} />
  <meta property="og:description" content={description} />
  <meta property="og:image" content={image} />
  <meta property="og:url" content={url} />

  <!-- Twitter -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content={title} />
  <meta name="twitter:description" content={description} />
  <meta name="twitter:image" content={image} />

  <!-- Canonical -->
  <link rel="canonical" href={url} />
</svelte:head>
```

## Structured data (JSON-LD)

Emit a schema.org object for rich results on content/product/article pages. Serialise the object so values stay escaped.

```svelte
<svelte:head>
  {@html `<script type="application/ld+json">${JSON.stringify({
    '@context': 'https://schema.org',
    '@type': 'Product',
    name: product.name,
    description: product.description,
    image: product.image,
    offers: {
      '@type': 'Offer',
      price: product.price.toFixed(2),
      priceCurrency: product.currency,
      availability: 'https://schema.org/InStock'
    }
  })}</script>`}
</svelte:head>
```

## Heading hierarchy

One `<h1>` per page (the page title); descend sequentially `h1 → h2 → h3` without skipping. Size visually with CSS, independent of semantic level.

## Core Web Vitals

- **LCP** — mark the above-the-fold hero image `loading="eager"` and `fetchpriority="high"`; lazy-load the rest.
- **CLS** — set `width`/`height` (or `aspect-ratio`) on every image to reserve space.
- **INP** — keep handlers fast; defer heavy work with `requestAnimationFrame`.

## Checklist

- [ ] Unique `<title>` and `<meta name="description">` on every page.
- [ ] Open Graph + Twitter tags for social sharing.
- [ ] Canonical URL on every public page.
- [ ] JSON-LD on content/product/article pages.
- [ ] Descriptive `alt` on all informative images (see `accessibility`).
- [ ] Images carry `width`/`height`; hero image is eager + high priority.
