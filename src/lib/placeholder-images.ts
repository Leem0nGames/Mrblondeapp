// Using a simple object for this, but this could be a more complex system
// that fetches images from a CMS or a dedicated image service.

type ImageType = 'product' | 'product_sm' | 'product_card' | 'cart_item' | 'summary_item';
type ImageParams = {
    id: string;
    width: number;
    height: number;
}

const placeholderSources: Record<ImageType, (params: ImageParams) => string> = {
    product: ({ id, width, height }) => `https://picsum.photos/seed/${id}/${width}/${height}`,
    product_sm: ({ id, width, height }) => `https://picsum.photos/seed/${id}/${width}/${height}`,
    product_card: ({ id, width, height }) => `https://picsum.photos/seed/${id}/${width}/${height}`,
    cart_item: ({ id, width, height }) => `https://picsum.photos/seed/${id}/${width}/${height}`,
    summary_item: ({ id, width, height }) => `https://picsum.photos/seed/${id}/${width}/${height}`,
}

export function getImageUrl(type: ImageType, params: ImageParams): string {
    const sourceFn = placeholderSources[type];
    if (!sourceFn) {
        // Fallback for an unknown type
        return `https://picsum.photos/${params.width}/${params.height}`;
    }
    return sourceFn(params);
}
