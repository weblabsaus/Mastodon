import { isAction } from 'redux';
import type { Middleware, UnknownAction } from 'redux';

import ready from 'mastodon/ready';
import { assetHost } from 'mastodon/utils/config';

import type { RootState } from '..';

interface AudioSource {
  src: string;
  type: string;
}

interface ActionWithMetaSound extends UnknownAction {
  meta: { sound: string };
}

function isActionWithMetaSound(action: unknown): action is ActionWithMetaSound {
  return (
    isAction(action) &&
    'meta' in action &&
    typeof action.meta === 'object' &&
    !!action.meta &&
    'sound' in action.meta &&
    typeof action.meta.sound === 'string'
  );
}

const createAudio = (sources: AudioSource[]) => {
  const audio = new Audio();
  sources.forEach(({ type, src }) => {
    const source = document.createElement('source');
    source.type = type;
    source.src = src;
    audio.appendChild(source);
  });
  return audio;
};

const play = (audio: HTMLAudioElement) => {
  if (!audio.paused) {
    audio.pause();
    if (typeof audio.fastSeek === 'function') {
      audio.fastSeek(0);
    } else {
      audio.currentTime = 0;
    }
  }

  void audio.play();
};

export const soundsMiddleware = (): Middleware<
  Record<string, never>,
  RootState
> => {
  const soundCache: Record<string, HTMLAudioElement> = {};

  void ready(() => {
    soundCache.boop = createAudio([
      {
        src: `${assetHost}/sounds/boop.ogg`,
        type: 'audio/ogg',
      },
      {
        src: `${assetHost}/sounds/boop.mp3`,
        type: 'audio/mpeg',
      },
    ]);
  });

  return () => (next) => (action) => {
    if (isActionWithMetaSound(action)) {
      const sound = action.meta.sound;

      if (sound && Object.hasOwn(soundCache, sound)) {
        play(soundCache[sound]);
      }
    }

    return next(action);
  };
};
