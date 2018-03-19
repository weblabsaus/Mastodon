import { connect } from 'react-redux';
import Upload from '../components/upload';
import { undoUploadCompose, changeUploadCompose } from '../../../actions/compose';
import { openModal } from '../../../actions/modal';

const mapStateToProps = (state, { id }) => ({
  media: state.compose.getIn('media_attachments').find(item => item.get('id') === id),
});

const mapDispatchToProps = dispatch => ({

  onUndo: id => {
    dispatch(undoUploadCompose(id));
  },

  onDescriptionChange: (id, description) => {
    dispatch(changeUploadCompose(id, { description }));
  },

  onOpenFocalPoint: id => {
    dispatch(openModal('FOCAL_POINT', { id }));
  },

});

export default connect(mapStateToProps, mapDispatchToProps)(Upload);
