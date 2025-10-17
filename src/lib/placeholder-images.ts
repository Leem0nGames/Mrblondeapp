
import placeholderData from './placeholder-images.json';

type ImageType = 'product' | 'product_sm' | 'product_card' | 'cart_item' | 'summary_item';
type ImageParams = {
    id: string;
    width: number;
    height: number;
}

const typedPlaceholderData = placeholderData as Record<ImageType, { seed: string }>;

export function getImageUrl(
    type: ImageType, 
    params: ImageParams,
    realImageUrl?: string | null
): string {
    if (realImageUrl) {
        return realImageUrl;
    }
    
    const seedInfo = typedPlaceholderData[type];
    const seed = seedInfo ? `${seedInfo.seed}_${params.id}` : params.id;
    
    return `https://picsum.photos/seed/${seed}/${params.width}/${params.height}`;
}
