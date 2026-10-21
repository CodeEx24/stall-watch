/** View models for the project detail page. Client-safe (no server imports). */
export type SlotSelection = {
  productName: string;
  lockVersion: number;
};

export type SlotView = {
  id: string;
  category: string;
  selection: SlotSelection | null;
};

export type RoomView = {
  room: string;
  slots: SlotView[];
};

export type ProjectDetail = {
  id: string;
  name: string;
  orgName: string;
  status: string;
  archivedAt: string | null;
  isStalled: boolean;
  rooms: RoomView[];
};
