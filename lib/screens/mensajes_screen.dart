import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/mensajes_service.dart';
import '../services/auth_service.dart';

class MensajesScreen extends StatefulWidget {
  final int idIncidente;
  const MensajesScreen({super.key, required this.idIncidente});

  @override
  State<MensajesScreen> createState() => _MensajesScreenState();
}

class _MensajesScreenState extends State<MensajesScreen> {
  final MensajesService _service = MensajesService();
  final AuthService _authService = AuthService();
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  List<MensajeModel> _mensajes = [];
  int? _miId;
  bool _cargando = true;
  bool _enviando = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargarUserId();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargarUserId() async {
    final id = await _authService.getUserId();
    setState(() => _miId = id != null ? int.tryParse(id) : null);
  }

  Future<void> _cargar() async {
    final lista = await _service.listar(widget.idIncidente);
    if (!mounted) return;
    setState(() {
      _mensajes = lista;
      _cargando = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty || _enviando) return;

    setState(() => _enviando = true);
    final nuevo = await _service.enviar(widget.idIncidente, texto);
    if (!mounted) return;

    if (nuevo != null) {
      _ctrl.clear();
      setState(() {
        _mensajes.add(nuevo);
        _enviando = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el mensaje')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mensajes — Incidente #${widget.idIncidente}'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _mensajes.isEmpty
                    ? const Center(child: Text('Sin mensajes aún. Escribe el primero.'))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: _mensajes.length,
                        itemBuilder: (_, i) => _buildBurbuja(_mensajes[i]),
                      ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildBurbuja(MensajeModel m) {
    final esMio = m.idUsuario == _miId;
    final hora = DateFormat('HH:mm dd/MM').format(m.createdAt.toLocal());

    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: esMio ? Colors.red.shade700 : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(esMio ? 16 : 4),
            bottomRight: Radius.circular(esMio ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              esMio ? 'Tú' : 'Taller',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: esMio ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              m.contenido,
              style: TextStyle(
                color: esMio ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hora,
              style: TextStyle(
                fontSize: 10,
                color: esMio ? Colors.white60 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _enviar(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            onPressed: _enviando ? null : _enviar,
            backgroundColor: Colors.red.shade700,
            child: _enviando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
