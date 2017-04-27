export const MODAL_OPEN  = 'MODAL_OPEN';
export const MODAL_CLOSE = 'MODAL_CLOSE';

export function openModal(type, props) {
  return {
    type: MODAL_OPEN,
    modalType: type,
    modalProps: props
  };
};

export function closeModal() {
  return {
    type: MODAL_CLOSE
  };
};
