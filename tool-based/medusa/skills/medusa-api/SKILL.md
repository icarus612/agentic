---
name: medusa-api
description: Integrate with the MedusaJS 2.x storefront API — products, cart, checkout, and authentication via the JS SDK. Use when wiring a storefront to a Medusa backend.
domain: medusa
rules: []
model: sonnet
model-fallback: [gemini-pro]
---

# MedusaJS 2.x Storefront API

## API Client Pattern

```typescript
// $lib/api/medusa.ts
const MEDUSA_URL = import.meta.env.VITE_MEDUSA_BACKEND_URL ?? 'http://localhost:9000';
const PUBLISHABLE_KEY = import.meta.env.VITE_MEDUSA_PUBLISHABLE_KEY;

interface MedusaFetchOptions {
  method?: string;
  body?: Record<string, unknown>;
  headers?: Record<string, string>;
}

async function medusaFetch<T>(path: string, options: MedusaFetchOptions = {}): Promise<T> {
  const response = await fetch(`${MEDUSA_URL}/store${path}`, {
    method: options.method ?? 'GET',
    headers: {
      'Content-Type': 'application/json',
      'x-publishable-api-key': PUBLISHABLE_KEY,
      ...options.headers,
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  if (!response.ok) {
    throw new Error(`Medusa API error: ${response.status}`);
  }
  return response.json() as Promise<T>;
}
```

## Products
```typescript
// List products
const { products } = await medusaFetch<{ products: Product[] }>('/products');

// Get single product by handle
const { products } = await medusaFetch<{ products: Product[] }>(`/products?handle=${handle}`);
```

## Cart Management
```typescript
// Create cart
const { cart } = await medusaFetch<{ cart: Cart }>('/carts', { method: 'POST' });

// Add line item
await medusaFetch(`/carts/${cartId}/line-items`, {
  method: 'POST',
  body: { variant_id: variantId, quantity: 1 },
});

// Update quantity
await medusaFetch(`/carts/${cartId}/line-items/${lineItemId}`, {
  method: 'POST',
  body: { quantity: newQuantity },
});
```

## Price Formatting
MedusaJS stores prices in **cents**. Convert to dollars for display:

```typescript
const CENTS_PER_DOLLAR = 100;

function formatPrice(amount: number, currencyCode: string = 'usd'): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currencyCode,
  }).format(amount / CENTS_PER_DOLLAR);
}
```

## Server-Side Fetching
Use `+page.server.ts` to fetch with internal URLs and forward cookies:

```typescript
export const load: PageServerLoad = async ({ cookies }) => {
  const cartId = cookies.get('cart_id');
  if (!cartId) return { cart: null };

  const { cart } = await medusaFetch<{ cart: Cart }>(`/carts/${cartId}`);
  return { cart };
};
```
