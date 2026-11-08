"use client";

// SF Symbol name → Phosphor icon. The iOS app stores SF Symbol strings in
// categories, toasts and settings; the web app renders Phosphor equivalents
// (fill weight for *.fill names). Unknown names fall back to a generic tile.

import type { IconProps } from "@phosphor-icons/react";
import {
  Airplane, ArrowsDownUp, ArrowCircleDown, ArrowCircleUp, ArrowClockwise, BellSimpleSlash, Book, Brain,
  Briefcase, Broadcast, CalendarBlank, Camera, Car, CaretRight, ChartBar, ChartPie, Check, CheckCircle,
  Clock, Cloud, CloudArrowUp, CloudCheck, CloudSlash, CloudWarning, Coffee, CreditCard, DotsThree,
  DownloadSimple, FileText, FilmSlate, Fingerprint, Folder, ForkKnife, GameController, Gear, Gift,
  GraduationCap, Heart, House, Link, ListBullets, Lock, MagnifyingGlass, MonitorPlay, MusicNote,
  Newspaper, NotePencil, PaintBrush, Pause, PauseCircle, PawPrint, PersonSimpleRun, Play, PlayCircle,
  Plus, PlusCircle, Question, SealCheck, ShieldCheck, ShoppingBag, ShoppingCart, Sparkle, SquaresFour,
  Stack, Table, Target, Tote, TrainRegional, Trash, Tray, UploadSimple, Warning, WifiHigh, WifiSlash,
  X, XCircle,
} from "@phosphor-icons/react";

const registry: Record<string, React.ComponentType<IconProps>> = {
  "house.fill": House,
  "chart.pie.fill": ChartPie,
  "gearshape.fill": Gear,
  "list.bullet": ListBullets,
  plus: Plus,
  "plus.circle.fill": PlusCircle,
  calendar: CalendarBlank,
  tray: Tray,
  "tray.full.fill": Tray,
  "checkmark.seal": SealCheck,
  "checkmark.circle": CheckCircle,
  "checkmark.circle.fill": CheckCircle,
  "clock.fill": Clock,
  target: Target,
  "exclamationmark.triangle.fill": Warning,
  "exclamationmark.circle.fill": Warning,
  "square.and.pencil": NotePencil,
  "creditcard.fill": CreditCard,
  ellipsis: DotsThree,
  "play.circle.fill": PlayCircle,
  "pause.fill": Pause,
  "pause.circle.fill": PauseCircle,
  "play.fill": Play,
  "xmark.circle": XCircle,
  "xmark.circle.fill": XCircle,
  xmark: X,
  checkmark: Check,
  "arrow.up.circle.fill": ArrowCircleUp,
  "arrow.down.circle.fill": ArrowCircleDown,
  "square.stack.3d.up.slash.fill": Stack,
  "chart.bar": ChartBar,
  "bell.slash.fill": BellSimpleSlash,
  "arrow.clockwise": ArrowClockwise,
  icloud: Cloud,
  "icloud.and.arrow.up.down": ArrowsDownUp,
  "checkmark.icloud.fill": CloudCheck,
  "exclamationmark.icloud": CloudWarning,
  "icloud.slash": CloudSlash,
  "icloud.and.arrow.up": CloudArrowUp,
  "arrow.clockwise.icloud": CloudArrowUp,
  folder: Folder,
  "square.and.arrow.up": UploadSimple,
  "square.and.arrow.down": DownloadSimple,
  tablecells: Table,
  trash: Trash,
  "trash.circle.fill": Trash,
  "lock.fill": Lock,
  lock: Lock,
  faceid: Fingerprint,
  "doc.text": FileText,
  link: Link,
  magnifyingglass: MagnifyingGlass,
  "chevron.right": CaretRight,
  "questionmark.circle": Question,
  "wifi.exclamationmark": WifiSlash,
  wifi: WifiHigh,
  "wifi.slash": WifiSlash,

  // category symbols
  "play.tv.fill": MonitorPlay,
  "music.note": MusicNote,
  sparkles: Sparkle,
  "brain.head.profile": Brain,
  "antenna.radiowaves.left.and.right": Broadcast,
  "gamecontroller.fill": GameController,
  "film.fill": FilmSlate,
  "book.fill": Book,
  "newspaper.fill": Newspaper,
  "cloud.fill": Cloud,
  "lock.shield.fill": ShieldCheck,
  "cart.fill": ShoppingCart,
  "bag.fill": ShoppingBag,
  "fork.knife": ForkKnife,
  "cup.and.saucer.fill": Coffee,
  "car.fill": Car,
  "tram.fill": TrainRegional,
  "figure.run": PersonSimpleRun,
  "heart.fill": Heart,
  "graduationcap.fill": GraduationCap,
  "briefcase.fill": Briefcase,
  "pawprint.fill": PawPrint,
  "gift.fill": Gift,
  "paintbrush.fill": PaintBrush,
  "camera.fill": Camera,
  airplane: Airplane,
  "square.grid.2x2.fill": SquaresFour,
  tote: Tote,
};

export function Sym({
  name,
  size = 17,
  weight,
  className,
  style,
}: {
  name: string;
  size?: number;
  weight?: IconProps["weight"];
  className?: string;
  style?: React.CSSProperties;
}) {
  const Comp = registry[name] ?? SquaresFour;
  return (
    <Comp
      size={size}
      weight={weight ?? (name.endsWith(".fill") ? "fill" : "regular")}
      className={className}
      style={style}
      aria-hidden
    />
  );
}
