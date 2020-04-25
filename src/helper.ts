import { StreamTransceiverFactory, StreamTransceiverFactoryArray } from "./types";

export function sanitizeStreamTransceivers(transceivers: StreamTransceiverFactory | StreamTransceiverFactoryArray | undefined): StreamTransceiverFactoryArray {
  if(transceivers == null) {
    return [];
  } else if(Array.isArray(transceivers)) {
    return transceivers;
  } else {
    return [transceivers];
  }
}
