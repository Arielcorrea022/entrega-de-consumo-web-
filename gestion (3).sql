-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 20-09-2025 a las 08:12:50
-- Versión del servidor: 10.4.32-MariaDB
-- Versión de PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `gestion`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `SP_ActualizarProducto` (IN `p_id_producto` INT, IN `p_nombre` VARCHAR(150), IN `p_precio` DECIMAL(10,2), IN `p_stock` INT, IN `p_usuario` VARCHAR(100))   BEGIN
    DECLARE v_stock INT;

    -- Stock anterior
    SELECT stock INTO v_stock
    FROM inventario
    WHERE id_producto = p_id_producto;

    -- Actualizar producto
    UPDATE productos
    SET nombre_producto = p_nombre,
        precio = p_precio
    WHERE id_producto = p_id_producto;

    -- Actualizar inventario
    UPDATE inventario
    SET stock = p_stock,
        ultima_actualizacion = NOW()
    WHERE id_producto = p_id_producto;

    -- Registrar histórico
    INSERT INTO Inventario_Historico (producto_id, stock_anterior, stock_nuevo)
    VALUES (p_id_producto, v_stock, p_stock);

    -- Registrar auditoría
    INSERT INTO Audit_Log (tabla, operacion, registro_id, usuario, descripcion)
    VALUES ('productos', 'UPDATE', p_id_producto, p_usuario, 'Actualización de producto');
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SP_BackupInventario` (IN `p_usuario` VARCHAR(100))   BEGIN
    -- Copiar estado actual a histórico
    INSERT INTO Inventario_Historico (producto_id, stock_anterior, stock_nuevo)
    SELECT id_producto, stock, stock
    FROM inventario;

    -- Registrar en auditoría
    INSERT INTO Audit_Log (tabla, operacion, usuario, descripcion)
    VALUES ('inventario', 'BACKUP', p_usuario, 'Respaldo completo del inventario');
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SP_InsertarVenta` (IN `p_id_producto` INT, IN `p_cantidad` INT, IN `p_usuario` VARCHAR(100))   BEGIN
    DECLARE v_stock INT;

    -- Consultar stock actual
    SELECT stock INTO v_stock
    FROM inventario
    WHERE id_producto = p_id_producto;

    -- Validar stock
    IF v_stock IS NULL OR v_stock < p_cantidad THEN
        INSERT INTO Error_Log (procedimiento, mensaje_error)
        VALUES ('SP_InsertarVenta', CONCAT('Stock insuficiente para producto ID: ', p_id_producto));
    ELSE
        -- Actualizar inventario
        UPDATE inventario
        SET stock = stock - p_cantidad,
            ultima_actualizacion = NOW()
        WHERE id_producto = p_id_producto;

        -- Registrar en histórico
        INSERT INTO Inventario_Historico (producto_id, stock_anterior, stock_nuevo)
        VALUES (p_id_producto, v_stock, v_stock - p_cantidad);

        -- Registrar en auditoría
        INSERT INTO Audit_Log (tabla, operacion, registro_id, usuario, descripcion)
        VALUES ('ventas', 'INSERT', p_id_producto, p_usuario, CONCAT('Venta de ', p_cantidad, ' unidades.'));
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SP_ReporteStockCritico` (IN `p_umbral` INT, IN `p_usuario` VARCHAR(100))   BEGIN
    -- Registrar consulta en auditoría
    INSERT INTO Audit_Log (tabla, operacion, usuario, descripcion)
    VALUES ('inventario', 'SELECT', p_usuario, CONCAT('Consulta de productos con stock menor a ', p_umbral));

    -- Devolver reporte
    SELECT p.id_producto, p.nombre_producto, i.stock
    FROM productos p
    JOIN inventario i ON p.id_producto = i.id_producto
    WHERE i.stock < p_umbral;
END$$

--
-- Funciones
--
CREATE DEFINER=`root`@`localhost` FUNCTION `FN_ObtenerStock` (`p_id_producto` INT) RETURNS INT(11) DETERMINISTIC BEGIN
    DECLARE v_stock INT;

    SELECT stock INTO v_stock
    FROM inventario
    WHERE id_producto = p_id_producto;

    RETURN v_stock;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `FN_RolUsuario` (`p_cedula` VARCHAR(20)) RETURNS VARCHAR(50) CHARSET utf8mb4 COLLATE utf8mb4_general_ci DETERMINISTIC BEGIN
    DECLARE v_rol VARCHAR(50);

    SELECT r.nombre_rol INTO v_rol
    FROM usuarios u
    JOIN roles r ON u.id_rol = r.id_rol
    WHERE u.cedula = p_cedula;

    RETURN v_rol;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `FN_TieneStock` (`p_id_producto` INT, `p_cantidad` INT) RETURNS TINYINT(1) DETERMINISTIC BEGIN
    DECLARE v_stock INT;

    SELECT stock INTO v_stock
    FROM inventario
    WHERE id_producto = p_id_producto;

    RETURN v_stock >= p_cantidad;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `FN_UltimaActualizacion` (`p_id_producto` INT) RETURNS DATETIME DETERMINISTIC BEGIN
    DECLARE v_fecha DATETIME;

    SELECT ultima_actualizacion INTO v_fecha
    FROM inventario
    WHERE id_producto = p_id_producto;

    RETURN v_fecha;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `FN_ValorInventario` () RETURNS DECIMAL(15,2) DETERMINISTIC BEGIN
    DECLARE v_total DECIMAL(15,2);

    SELECT SUM(p.precio * i.stock) INTO v_total
    FROM productos p
    JOIN inventario i ON p.id_producto = i.id_producto;

    RETURN IFNULL(v_total,0);
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `administracion`
--

CREATE TABLE `administracion` (
  `id_admin` int(11) NOT NULL,
  `cedula_usuario` varchar(20) NOT NULL,
  `fecha` datetime DEFAULT NULL,
  `accion` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `audit_log`
--

CREATE TABLE `audit_log` (
  `log_id` int(11) NOT NULL,
  `tabla` varchar(50) DEFAULT NULL,
  `operacion` varchar(20) DEFAULT NULL,
  `registro_id` int(11) DEFAULT NULL,
  `usuario` varchar(100) DEFAULT NULL,
  `fecha` timestamp NOT NULL DEFAULT current_timestamp(),
  `descripcion` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `audit_log`
--

INSERT INTO `audit_log` (`log_id`, `tabla`, `operacion`, `registro_id`, `usuario`, `fecha`, `descripcion`) VALUES
(1, 'productos', 'INSERT', 1, '1234567890', '2025-09-20 06:04:01', 'Producto agregado con stock inicial');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `categorias`
--

CREATE TABLE `categorias` (
  `id_categoria` int(11) NOT NULL,
  `nombre_categoria` varchar(100) NOT NULL,
  `descripcion` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `categorias`
--

INSERT INTO `categorias` (`id_categoria`, `nombre_categoria`, `descripcion`) VALUES
(1, 'viveres', 'lacteos');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `error_log`
--

CREATE TABLE `error_log` (
  `error_id` int(11) NOT NULL,
  `procedimiento` varchar(100) DEFAULT NULL,
  `mensaje_error` text DEFAULT NULL,
  `fecha` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `inventario`
--

CREATE TABLE `inventario` (
  `id_inventario` int(11) NOT NULL,
  `id_producto` int(11) NOT NULL,
  `stock` int(11) NOT NULL,
  `ultima_actualizacion` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `inventario`
--

INSERT INTO `inventario` (`id_inventario`, `id_producto`, `stock`, `ultima_actualizacion`) VALUES
(1, 1, 2, '2025-09-20 01:04:01');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `inventario_historico`
--

CREATE TABLE `inventario_historico` (
  `hist_id` int(11) NOT NULL,
  `producto_id` int(11) DEFAULT NULL,
  `stock_anterior` int(11) DEFAULT NULL,
  `stock_nuevo` int(11) DEFAULT NULL,
  `fecha` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `productos`
--

CREATE TABLE `productos` (
  `id_producto` int(11) NOT NULL,
  `nombre_producto` varchar(150) NOT NULL,
  `descripcion` text DEFAULT NULL,
  `precio` decimal(10,2) NOT NULL,
  `id_categoria` int(11) NOT NULL,
  `id_proveedor` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `productos`
--

INSERT INTO `productos` (`id_producto`, `nombre_producto`, `descripcion`, `precio`, `id_categoria`, `id_proveedor`) VALUES
(1, 'queso', 'costeño', 15000.00, 1, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `proveedores`
--

CREATE TABLE `proveedores` (
  `id_proveedor` int(11) NOT NULL,
  `nombre_proveedor` varchar(150) NOT NULL,
  `telefono` varchar(20) DEFAULT NULL,
  `correo` varchar(100) DEFAULT NULL,
  `direccion` varchar(200) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `proveedores`
--

INSERT INTO `proveedores` (`id_proveedor`, `nombre_proveedor`, `telefono`, `correo`, `direccion`) VALUES
(1, 'Luis delgado', '3147426653', 'luis@gmail.com', 'Quibdo');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `roles`
--

CREATE TABLE `roles` (
  `id_rol` int(11) NOT NULL,
  `nombre_rol` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `roles`
--

INSERT INTO `roles` (`id_rol`, `nombre_rol`) VALUES
(1, 'Administrador');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuarios`
--

CREATE TABLE `usuarios` (
  `cedula` varchar(20) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `correo` varchar(100) NOT NULL,
  `contraseña` varchar(255) NOT NULL,
  `id_rol` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `usuarios`
--

INSERT INTO `usuarios` (`cedula`, `nombre`, `correo`, `contraseña`, `id_rol`) VALUES
('1001846889', 'Ariel', 'arielcorreama@gmail.com', '$2y$10$K/.dgdTDTAD42MkCejSqb.T02KnQ5CVKBVBUKhaX3qG/ptei6wGfK', 1),
('1234567890', 'Admin', 'admin@correo.com', '$2y$10$qLC39CgmcqgwmshbEzEod.TjLH9INq4cGW1Xt1.kw8QWj0EHMviZ2', 1);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vw_auditoriausuarios`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vw_auditoriausuarios` (
`log_id` int(11)
,`tabla` varchar(50)
,`operacion` varchar(20)
,`registro_id` int(11)
,`usuario` varchar(100)
,`fecha` timestamp
,`descripcion` text
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vw_errores`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vw_errores` (
`error_id` int(11)
,`procedimiento` varchar(100)
,`mensaje_error` text
,`fecha` timestamp
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vw_historicoinventario`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vw_historicoinventario` (
`hist_id` int(11)
,`nombre_producto` varchar(150)
,`stock_anterior` int(11)
,`stock_nuevo` int(11)
,`fecha` timestamp
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vw_productosinventario`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vw_productosinventario` (
`id_producto` int(11)
,`nombre_producto` varchar(150)
,`precio` decimal(10,2)
,`stock` int(11)
,`ultima_actualizacion` datetime
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vw_stockcritico`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vw_stockcritico` (
`id_producto` int(11)
,`nombre_producto` varchar(150)
,`stock` int(11)
);

-- --------------------------------------------------------

--
-- Estructura para la vista `vw_auditoriausuarios`
--
DROP TABLE IF EXISTS `vw_auditoriausuarios`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_auditoriausuarios`  AS SELECT `a`.`log_id` AS `log_id`, `a`.`tabla` AS `tabla`, `a`.`operacion` AS `operacion`, `a`.`registro_id` AS `registro_id`, `a`.`usuario` AS `usuario`, `a`.`fecha` AS `fecha`, `a`.`descripcion` AS `descripcion` FROM `audit_log` AS `a` ORDER BY `a`.`fecha` DESC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vw_errores`
--
DROP TABLE IF EXISTS `vw_errores`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_errores`  AS SELECT `e`.`error_id` AS `error_id`, `e`.`procedimiento` AS `procedimiento`, `e`.`mensaje_error` AS `mensaje_error`, `e`.`fecha` AS `fecha` FROM `error_log` AS `e` ORDER BY `e`.`fecha` DESC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vw_historicoinventario`
--
DROP TABLE IF EXISTS `vw_historicoinventario`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_historicoinventario`  AS SELECT `h`.`hist_id` AS `hist_id`, `p`.`nombre_producto` AS `nombre_producto`, `h`.`stock_anterior` AS `stock_anterior`, `h`.`stock_nuevo` AS `stock_nuevo`, `h`.`fecha` AS `fecha` FROM (`inventario_historico` `h` join `productos` `p` on(`h`.`producto_id` = `p`.`id_producto`)) ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vw_productosinventario`
--
DROP TABLE IF EXISTS `vw_productosinventario`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_productosinventario`  AS SELECT `p`.`id_producto` AS `id_producto`, `p`.`nombre_producto` AS `nombre_producto`, `p`.`precio` AS `precio`, `i`.`stock` AS `stock`, `i`.`ultima_actualizacion` AS `ultima_actualizacion` FROM (`productos` `p` join `inventario` `i` on(`p`.`id_producto` = `i`.`id_producto`)) ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vw_stockcritico`
--
DROP TABLE IF EXISTS `vw_stockcritico`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_stockcritico`  AS SELECT `p`.`id_producto` AS `id_producto`, `p`.`nombre_producto` AS `nombre_producto`, `i`.`stock` AS `stock` FROM (`productos` `p` join `inventario` `i` on(`p`.`id_producto` = `i`.`id_producto`)) WHERE `i`.`stock` < 5 ;

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `administracion`
--
ALTER TABLE `administracion`
  ADD PRIMARY KEY (`id_admin`),
  ADD KEY `cedula_usuario` (`cedula_usuario`);

--
-- Indices de la tabla `audit_log`
--
ALTER TABLE `audit_log`
  ADD PRIMARY KEY (`log_id`);

--
-- Indices de la tabla `categorias`
--
ALTER TABLE `categorias`
  ADD PRIMARY KEY (`id_categoria`),
  ADD UNIQUE KEY `nombre_categoria` (`nombre_categoria`);

--
-- Indices de la tabla `error_log`
--
ALTER TABLE `error_log`
  ADD PRIMARY KEY (`error_id`);

--
-- Indices de la tabla `inventario`
--
ALTER TABLE `inventario`
  ADD PRIMARY KEY (`id_inventario`),
  ADD KEY `id_producto` (`id_producto`);

--
-- Indices de la tabla `inventario_historico`
--
ALTER TABLE `inventario_historico`
  ADD PRIMARY KEY (`hist_id`),
  ADD KEY `producto_id` (`producto_id`);

--
-- Indices de la tabla `productos`
--
ALTER TABLE `productos`
  ADD PRIMARY KEY (`id_producto`),
  ADD KEY `id_categoria` (`id_categoria`),
  ADD KEY `id_proveedor` (`id_proveedor`);

--
-- Indices de la tabla `proveedores`
--
ALTER TABLE `proveedores`
  ADD PRIMARY KEY (`id_proveedor`);

--
-- Indices de la tabla `roles`
--
ALTER TABLE `roles`
  ADD PRIMARY KEY (`id_rol`),
  ADD UNIQUE KEY `nombre_rol` (`nombre_rol`);

--
-- Indices de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`cedula`),
  ADD UNIQUE KEY `correo` (`correo`),
  ADD KEY `id_rol` (`id_rol`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `administracion`
--
ALTER TABLE `administracion`
  MODIFY `id_admin` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `audit_log`
--
ALTER TABLE `audit_log`
  MODIFY `log_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `categorias`
--
ALTER TABLE `categorias`
  MODIFY `id_categoria` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `error_log`
--
ALTER TABLE `error_log`
  MODIFY `error_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `inventario`
--
ALTER TABLE `inventario`
  MODIFY `id_inventario` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `inventario_historico`
--
ALTER TABLE `inventario_historico`
  MODIFY `hist_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `productos`
--
ALTER TABLE `productos`
  MODIFY `id_producto` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `proveedores`
--
ALTER TABLE `proveedores`
  MODIFY `id_proveedor` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `roles`
--
ALTER TABLE `roles`
  MODIFY `id_rol` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `administracion`
--
ALTER TABLE `administracion`
  ADD CONSTRAINT `administracion_ibfk_1` FOREIGN KEY (`cedula_usuario`) REFERENCES `usuarios` (`cedula`);

--
-- Filtros para la tabla `inventario`
--
ALTER TABLE `inventario`
  ADD CONSTRAINT `inventario_ibfk_1` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`);

--
-- Filtros para la tabla `inventario_historico`
--
ALTER TABLE `inventario_historico`
  ADD CONSTRAINT `inventario_historico_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`id_producto`);

--
-- Filtros para la tabla `productos`
--
ALTER TABLE `productos`
  ADD CONSTRAINT `productos_ibfk_1` FOREIGN KEY (`id_categoria`) REFERENCES `categorias` (`id_categoria`),
  ADD CONSTRAINT `productos_ibfk_2` FOREIGN KEY (`id_proveedor`) REFERENCES `proveedores` (`id_proveedor`);

--
-- Filtros para la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD CONSTRAINT `usuarios_ibfk_1` FOREIGN KEY (`id_rol`) REFERENCES `roles` (`id_rol`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
