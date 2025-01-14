

const modal = function (title, message, modal_type, status, resolve_func) {
  const modal_footer = $('<div>', { class: 'modal-footer' });
  const modal_body = $('<div>', { class: 'modal-body' });
  const dfd = $.Deferred();
  let resolve;
  if (resolve_func) {
    resolve = resolve_func(dfd);
  } else {
    resolve = function () { dfd.resolve(); };
  }
  if (modal_type === 0 || modal_type === 1) {
    modal_footer.append($('<button>', { class: 'btn btn-default', 'data-dismiss': 'modal', text: 'Cancel' }));
  }
  if (message instanceof jQuery || modal_type === 1 || modal_type === 3) {
    modal_body.append($('<div>', { html: message }));
  } else {
    modal_body.append($('<div>', { text: message }));
  }
  modal_footer.append($('<button>', {
    class: 'btn btn-primary', 'data-dismiss': 'modal', text: 'OK', click: resolve,
  }));
  let additional_class = '';
  if (status === 'warning') {
    additional_class = 'bg-warning';
  } else if (status === 'danger') {
    additional_class = 'bg-danger';
  }
  const modal_base = $('<div>', { class: 'modal fade', 'data-backdrop': 'static' }).append($('<div>', { class: 'modal-dialog' }).append($('<div>', { class: 'modal-content' }).append($('<div>', { class: `modal-header ${additional_class}` }).append($('<button>', { class: 'close', 'data-dismiss': 'modal' }).append($('<span>', { 'aria-hidden': 'true', html: '&times;' })).append($('<span>', { class: 'sr-only', text: 'Close' }))).append($('<h4>', { class: 'modal-title', text: title }))).append(modal_body).append(modal_footer)));
  modal_base.on('hidden.bs.modal', (e) => {
    modal_base.remove();
  });
  modal_base.appendTo('body').modal('show');
  modal_base.children().draggable({
    cursor: 'move',
    containment: '.modal-backdrop',
    handle: '.modal-header',
  });
  return dfd;
};
function Confirm(title, message, status) {
  return modal(title, message, 0, status);
}
exports.Confirm = Confirm;

function Alert(title, message, status) {
  return modal(title, message, 2, status);
}
exports.Alert = Alert;

function ConfirmHTML(title, message, status) {
  return modal(title, message, 1, status);
}
exports.ConfirmHTML = ConfirmHTML;

function AlertHTML(title, message, status) {
  return modal(title, message, 3, status);
}
exports.AlertHTML = AlertHTML;

function Prompt(title, label, status) {
  const input_id = _.uniqueId('bootstrap_prompt_');
  const input = $('<form>', { class: 'form-horizontal' }).append($('<div>', { class: 'form-group' }).append($('<label>', { class: 'control-label col-sm-2', for: input_id, text: label })).append($('<div>', { class: 'col-sm-5' }).append($('<input>', { class: 'form-control', type: 'text', id: input_id }))));
  const resolve_func = function (dfd) {
    return function () {
      const text = document.getElementById(input_id).value;
      dfd.resolve(text);
    };
  };
  const dfd = modal(title, input, 1, status, resolve_func);
  input.on('keypress', (e) => {
    const ENTER = 13;
    if ((e.which && e.which === ENTER) || (e.keyCode && e.keyCode === ENTER)) {
      input.closest('.modal').modal('hide');
      resolve_func(dfd)();
      return false;
    }
    return true;
  });
  return dfd;
}
exports.Prompt = Prompt;

function AlertForAjaxStdError(callback) {
  return function (xhr) {
    const t = typeof xhr === 'string' ? xhr : xhr.responseText;
    const ex = JSON.parse(t).error;
    const dfd = Alert(ex.kind, _.escape(ex.message), 'danger');
    if (callback) {
      dfd.done(callback);
    }
  };
}
exports.AlertForAjaxStdError = AlertForAjaxStdError;
