// Drives the "in action" gallery + lightbox. Each item is a tile in
// the grid and a slide in the lightbox. `src`/`thumb`/`poster` are resolved
// against import.meta.env.BASE_URL in the component, so give plain filenames
// that live in `public/`.

export type GalleryItem = {
  type: "image" | "video";
  src: string;
  thumb?: string;
  poster?: string;
  title: string;
  caption: string;
  width: number;
  height: number;
};

export const galleryItems: GalleryItem[] = [
  {
    type: "video",
    src: "tinycast-in-action.mp4",
    poster: "screenshot.png",
    title: "Tinycast in action",
    caption: "A quick tour of the launcher palette.",
    width: 3024,
    height: 1964,
  },
  {
    type: "image",
    src: "screenshot.png",
    title: "App launcher",
    caption: "Fuzzy-search apps, Settings panes, and system actions.",
    width: 3024,
    height: 1964,
  },
  {
    type: "image",
    src: "per-app-hotkey.png",
    title: "Per-app hotkeys",
    caption: "Bind a key to an app: press to focus, again to hide.",
    width: 2212,
    height: 1606,
  },
  {
    type: "image",
    src: "ram-usage.png",
    title: "Featherweight",
    caption: "Under 100 MB of memory, a few megabytes on disk.",
    width: 2558,
    height: 1754,
  },
];
