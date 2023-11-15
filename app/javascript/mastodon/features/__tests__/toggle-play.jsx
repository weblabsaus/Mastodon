import PropTypes from 'prop-types';
import { useCallback, useState } from 'react';

import { render, fireEvent } from '@testing-library/react';

function Media({ onClick, paused: initialPaused = false, title }) {
  const [paused, setPaused] = useState(initialPaused);

  const handleMediaClick = useCallback(() => {
    setPaused(prevState => !prevState);

    if (typeof onClick === 'function') {
      onClick();
    }

    const mediaElements = document.querySelectorAll(`div[title="${title}"]`);

    setTimeout(() => {
      mediaElements.forEach(element => {
        if (element !== this && !element.classList.contains('paused')) {
          element.click();
        }
      });
    }, 0);
  }, [onClick, title]);

  return (
    <button title={title} onClick={handleMediaClick}>
      Media Component - {paused ? 'Paused' : 'Playing'}
    </button>
  );
}

Media.propTypes = {
  title: PropTypes.string.isRequired,
  onClick: PropTypes.func,
  paused: PropTypes.bool,
};

describe('Media attachments test', () => {
  let currentMedia = null;
  const togglePlayMock = jest.fn();

  it('plays a new media file and pauses others that were playing', () => {
    const container = render(
      <div>
        <Media title='firstMedia' paused onClick={togglePlayMock} />
        <Media title='secondMedia' paused onClick={togglePlayMock} />
      </div>,
    );

    fireEvent.click(container.getByTitle('firstMedia'));
    expect(togglePlayMock).toHaveBeenCalledTimes(1);
    currentMedia = container.getByTitle('firstMedia');
    expect(currentMedia.textContent).toMatch(/Playing/);

    fireEvent.click(container.getByTitle('secondMedia'));
    expect(togglePlayMock).toHaveBeenCalledTimes(2);
    currentMedia = container.getByTitle('secondMedia');
    expect(currentMedia.textContent).toMatch(/Playing/);
  });
});
